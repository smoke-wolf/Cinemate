"""Book library API routes — FastAPI router for e-books/digital books."""

import asyncio
import os
import re
from datetime import datetime
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel

from database import get_db
from book_scanner import book_scan_state, scan_books_directory

router = APIRouter(prefix="/api/books", tags=["books"])


# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------

class BookScanRequest(BaseModel):
    path: str


class ReadingProgressUpdate(BaseModel):
    progress: float  # 0.0 - 1.0
    current_page: Optional[int] = None


class BookmarkCreate(BaseModel):
    page: int
    note: Optional[str] = None


class ReadingTimeUpdate(BaseModel):
    seconds: float


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def row_to_dict(row) -> dict:
    if row is None:
        return {}
    return dict(row)


# ===========================================================================
# BOOK LIBRARY
# ===========================================================================

@router.get("")
async def list_books(
    search: Optional[str] = None,
    sort: str = Query("date_added", pattern="^(title|author|date_added|year|file_size|page_count)$"),
    order: str = Query("desc", pattern="^(asc|desc)$"),
    format: Optional[str] = None,
    genre: Optional[str] = None,
    author: Optional[str] = None,
    account_id: Optional[int] = None,
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
):
    """List all books with filtering, sorting, and pagination."""
    db = await get_db()
    try:
        conditions = []
        params = []

        if search:
            conditions.append("(b.title LIKE ? OR b.author LIKE ?)")
            params.extend([f"%{search}%", f"%{search}%"])
        if format:
            conditions.append("b.format = ?")
            params.append(format.upper())
        if genre:
            conditions.append("b.genre LIKE ?")
            params.append(f"%{genre}%")
        if author:
            conditions.append("b.author LIKE ?")
            params.append(f"%{author}%")

        where = " WHERE " + " AND ".join(conditions) if conditions else ""

        if account_id is not None:
            join = f" LEFT JOIN book_account_data bad ON b.id = bad.book_id AND bad.account_id = {int(account_id)}"
            select = "b.*, COALESCE(bad.favorite, 0) as favorite, COALESCE(bad.reading_progress, 0.0) as reading_progress, COALESCE(bad.current_page, 0) as current_page, COALESCE(bad.finished, 0) as finished"
        else:
            join = ""
            select = "b.*"

        order_col = f"b.{sort}" if sort != "date_added" else "b.date_added"
        order_clause = f" ORDER BY {order_col} {order.upper()}"

        cursor = await db.execute(f"SELECT COUNT(*) as cnt FROM books b{join}{where}", params)
        total = (await cursor.fetchone())["cnt"]

        cursor = await db.execute(
            f"SELECT {select} FROM books b{join}{where}{order_clause} LIMIT ? OFFSET ?",
            params + [limit, offset],
        )
        rows = await cursor.fetchall()
        items = []
        for r in rows:
            d = row_to_dict(r)
            if "favorite" in d:
                d["favorite"] = bool(d["favorite"])
            if "finished" in d:
                d["finished"] = bool(d["finished"])
            items.append(d)

        return {
            "items": items,
            "total": total,
            "limit": limit,
            "offset": offset,
        }
    finally:
        await db.close()


@router.get("/authors")
async def list_authors():
    """List all authors with book counts."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT author, COUNT(*) as book_count FROM books "
            "WHERE author IS NOT NULL AND author != '' "
            "GROUP BY author ORDER BY book_count DESC"
        )
        rows = await cursor.fetchall()
        return {"authors": [row_to_dict(r) for r in rows]}
    finally:
        await db.close()


@router.get("/authors/{name}")
async def get_author_books(name: str):
    """Get all books by an author."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM books WHERE author LIKE ? ORDER BY year DESC, title ASC",
            (f"%{name}%",),
        )
        rows = await cursor.fetchall()
        return {"author": name, "books": [row_to_dict(r) for r in rows]}
    finally:
        await db.close()


@router.get("/genres")
async def list_genres():
    """Genre breakdown with counts."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT genre, COUNT(*) as count FROM books WHERE genre IS NOT NULL "
            "AND genre != '' GROUP BY genre ORDER BY count DESC"
        )
        rows = await cursor.fetchall()
        return {"genres": [row_to_dict(r) for r in rows]}
    finally:
        await db.close()


@router.post("/scan")
async def start_book_scan(req: BookScanRequest):
    """Trigger a book directory scan in the background."""
    path = req.path
    if not os.path.isdir(path):
        raise HTTPException(400, f"Directory not found: {path}")
    if book_scan_state.scanning:
        raise HTTPException(409, "Book scan already in progress")

    asyncio.create_task(scan_books_directory(path))
    return {"status": "book_scan_started", "path": path}


@router.get("/scan/status")
async def get_book_scan_status():
    """Get current book scan progress."""
    return book_scan_state.to_dict()


@router.get("/stats")
async def get_book_stats():
    """Library-wide book statistics."""
    db = await get_db()
    try:
        stats = {}

        cursor = await db.execute("SELECT COUNT(*) as total FROM books")
        stats["total_books"] = (await cursor.fetchone())["total"]

        cursor = await db.execute(
            "SELECT COUNT(DISTINCT author) as c FROM books WHERE author IS NOT NULL"
        )
        stats["total_authors"] = (await cursor.fetchone())["c"]

        cursor = await db.execute("SELECT COALESCE(SUM(page_count), 0) as p FROM books")
        stats["total_pages"] = (await cursor.fetchone())["p"]

        cursor = await db.execute("SELECT COALESCE(SUM(file_size), 0) as s FROM books")
        total_bytes = (await cursor.fetchone())["s"]
        stats["total_size_bytes"] = total_bytes
        stats["total_size_gb"] = round(total_bytes / (1024 ** 3), 2)

        cursor = await db.execute(
            "SELECT format, COUNT(*) as count FROM books GROUP BY format ORDER BY count DESC"
        )
        stats["format_breakdown"] = [row_to_dict(r) for r in await cursor.fetchall()]

        return stats
    finally:
        await db.close()


@router.get("/cover/{book_id}")
async def get_book_cover(book_id: int):
    """Serve cover image for a book."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT cover_path FROM books WHERE id = ?", (book_id,)
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Book not found")
    finally:
        await db.close()

    cover = row["cover_path"]
    if not cover or not os.path.exists(cover):
        raise HTTPException(404, "Cover not available")

    ext = Path(cover).suffix.lower()
    media_types = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png"}
    media_type = media_types.get(ext, "image/jpeg")
    return FileResponse(cover, media_type=media_type)


@router.get("/read/{book_id}")
async def read_book(book_id: int, request: Request):
    """Serve the actual book file with Range support for PDFs."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT file_path, format FROM books WHERE id = ?", (book_id,)
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Book not found")
    finally:
        await db.close()

    file_path = row["file_path"]
    if not os.path.exists(file_path):
        raise HTTPException(404, f"File not found on disk: {file_path}")

    file_size = os.path.getsize(file_path)
    ext = Path(file_path).suffix.lower()
    content_types = {
        ".epub": "application/epub+zip",
        ".pdf": "application/pdf",
        ".mobi": "application/x-mobipocket-ebook",
        ".azw3": "application/vnd.amazon.ebook",
        ".fb2": "application/xml",
        ".djvu": "image/vnd.djvu",
        ".cbz": "application/vnd.comicbook+zip",
        ".cbr": "application/vnd.comicbook-rar",
    }
    content_type = content_types.get(ext, "application/octet-stream")

    range_header = request.headers.get("range")

    if range_header:
        range_spec = range_header.replace("bytes=", "")
        parts = range_spec.split("-")
        start = int(parts[0]) if parts[0] else 0
        end = int(parts[1]) if parts[1] else file_size - 1
        end = min(end, file_size - 1)
        chunk_size = end - start + 1

        async def ranged_file():
            with open(file_path, "rb") as f:
                f.seek(start)
                remaining = chunk_size
                while remaining > 0:
                    read_size = min(remaining, 1024 * 1024)
                    data = f.read(read_size)
                    if not data:
                        break
                    remaining -= len(data)
                    yield data

        return StreamingResponse(
            ranged_file(),
            status_code=206,
            headers={
                "Content-Range": f"bytes {start}-{end}/{file_size}",
                "Accept-Ranges": "bytes",
                "Content-Length": str(chunk_size),
                "Content-Type": content_type,
            },
        )
    else:
        return FileResponse(
            file_path,
            media_type=content_type,
            headers={
                "Accept-Ranges": "bytes",
                "Content-Length": str(file_size),
            },
        )


@router.get("/read/{book_id}/epub")
async def read_epub_html(book_id: int, chapter: int = 0):
    """Convert EPUB to HTML for web/iOS rendering. Returns full HTML page."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT file_path, format, title FROM books WHERE id = ?", (book_id,)
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Book not found")
    finally:
        await db.close()

    if row["format"] != "EPUB":
        raise HTTPException(400, "Not an EPUB file")

    file_path = row["file_path"]
    if not os.path.exists(file_path):
        raise HTTPException(404, "File not found on disk")

    try:
        import ebooklib
        from ebooklib import epub

        book = epub.read_epub(file_path)

        html_items = []
        for item in book.get_items():
            if item.get_type() == ebooklib.ITEM_DOCUMENT:
                html_items.append(item)

        if chapter < 0 or chapter >= len(html_items):
            chapter = 0

        content = html_items[chapter].get_content().decode("utf-8", errors="replace")

        # Inline CSS from the EPUB
        css_content = ""
        for item in book.get_items():
            if item.get_type() == ebooklib.ITEM_STYLE:
                css_content += item.get_content().decode("utf-8", errors="replace") + "\n"

        import base64 as b64mod
        image_map = {}
        for item in book.get_items():
            if item.get_type() == ebooklib.ITEM_IMAGE:
                data = item.get_content()
                mime = item.media_type or "image/jpeg"
                encoded = b64mod.b64encode(data).decode("ascii")
                image_map[item.get_name()] = f"data:{mime};base64,{encoded}"

        # Replace image src references with base64 data URIs
        import html as html_mod
        for orig_name, data_uri in image_map.items():
            basename = Path(orig_name).name
            content = content.replace(f'src="{orig_name}"', f'src="{data_uri}"')
            content = content.replace(f'src="{basename}"', f'src="{data_uri}"')
            content = content.replace(f"src='../{orig_name}'", f'src="{data_uri}"')
            for prefix in ["../", "./", "images/", "Images/", "OEBPS/", "OPS/"]:
                content = content.replace(f'src="{prefix}{basename}"', f'src="{data_uri}"')

        full_html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  body {{
    font-family: Georgia, 'Times New Roman', serif;
    line-height: 1.7;
    padding: 16px 20px 60px 20px;
    max-width: 100%;
    word-wrap: break-word;
    overflow-wrap: break-word;
  }}
  body.dark {{
    background: #1C1C1E;
    color: #E5E5E7;
  }}
  body.light {{
    background: #FAFAFA;
    color: #1C1C1E;
  }}
  img {{ max-width: 100%; height: auto; }}
  h1, h2, h3 {{ line-height: 1.3; }}
  a {{ color: #D4A843; }}
  {css_content}
</style>
</head>
<body class="dark">
{content}
</body>
</html>"""

        from fastapi.responses import HTMLResponse
        return HTMLResponse(
            content=full_html,
            headers={
                "X-Total-Chapters": str(len(html_items)),
                "X-Current-Chapter": str(chapter),
                "X-Book-Title": row["title"] or "",
            },
        )

    except ImportError:
        raise HTTPException(500, "ebooklib not installed on server")
    except Exception as e:
        logger.error(f"EPUB rendering failed for {book_id}: {e}")
        raise HTTPException(500, f"Failed to render EPUB: {str(e)}")


FRONT_MATTER_PATTERNS = re.compile(
    r"^(cover|title[ _-]?page|half[ _-]?title|copyright|dedication|"
    r"acknowledgment|about|frontmatter|front[ _-]?matter|"
    r"colophon|blurb|endorsement|also[ _-]by|titlepage|nav|toc|"
    r"table[ _-]of[ _-]contents?)$",
    re.IGNORECASE,
)

CONTENT_START_PATTERNS = re.compile(
    r"^(chapter|prologue|preface|foreword|introduction|part|book|"
    r"ch[\s._-]?\d|i{1,3}\.?\s|1[\s.])",
    re.IGNORECASE,
)


def _extract_chapter_title_from_html(html_bytes: bytes) -> Optional[str]:
    """Try to pull a heading from the HTML content."""
    text = html_bytes.decode("utf-8", errors="replace")
    for tag in ["h1", "h2", "h3"]:
        m = re.search(rf"<{tag}[^>]*>(.*?)</{tag}>", text, re.IGNORECASE | re.DOTALL)
        if m:
            title = re.sub(r"<[^>]+>", "", m.group(1)).strip()
            if title and len(title) < 120:
                return title
    return None


def _build_smart_toc(book, doc_items) -> list[dict]:
    """Build a TOC with real titles and smart first-chapter detection."""
    href_to_idx: dict[str, int] = {}
    for i, item in enumerate(doc_items):
        href_to_idx[item.get_name()] = i
        href_to_idx[Path(item.get_name()).name] = i

    chapters: list[dict] = []

    # Try the EPUB's own TOC first (re-read with NCX)
    toc = book.toc
    if toc:
        def _walk_toc(entries):
            for entry in entries:
                if isinstance(entry, tuple):
                    section, subs = entry
                    href = getattr(section, "href", "").split("#")[0]
                    idx = href_to_idx.get(href, href_to_idx.get(Path(href).name, -1))
                    if idx >= 0:
                        chapters.append({"index": idx, "title": section.title or ""})
                    _walk_toc(subs)
                else:
                    href = getattr(entry, "href", "").split("#")[0]
                    idx = href_to_idx.get(href, href_to_idx.get(Path(href).name, -1))
                    if idx >= 0:
                        chapters.append({"index": idx, "title": entry.title or ""})
        _walk_toc(toc)

    # If TOC worked, clean up titles and detect content start
    if chapters:
        for ch in chapters:
            if not ch["title"]:
                item = doc_items[ch["index"]] if ch["index"] < len(doc_items) else None
                if item:
                    ch["title"] = _extract_chapter_title_from_html(item.get_content()) or f"Chapter {ch['index'] + 1}"
    else:
        # No TOC — build from document items, extract headings
        for i, item in enumerate(doc_items):
            title = _extract_chapter_title_from_html(item.get_content())
            if not title:
                name = Path(item.get_name()).stem
                title = re.sub(r"[_-]", " ", name).strip().title()
            chapters.append({"index": i, "title": title})

    # Mark front matter vs content
    first_content_idx = 0
    for i, ch in enumerate(chapters):
        title_lower = ch["title"].lower().strip()
        fname = doc_items[ch["index"]].get_name().lower() if ch["index"] < len(doc_items) else ""
        fname_stem = Path(fname).stem.lower()

        is_front = FRONT_MATTER_PATTERNS.match(title_lower) or FRONT_MATTER_PATTERNS.match(fname_stem)
        is_content = CONTENT_START_PATTERNS.match(title_lower)

        ch["is_front_matter"] = bool(is_front) and not is_content
        if is_content and first_content_idx == 0:
            first_content_idx = i

    # If no content patterns matched, first non-front-matter chapter is content start
    if first_content_idx == 0:
        for i, ch in enumerate(chapters):
            if not ch.get("is_front_matter"):
                first_content_idx = i
                break

    return chapters, first_content_idx


@router.get("/read/{book_id}/toc")
async def epub_toc(book_id: int):
    """Get table of contents for an EPUB with smart chapter detection."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT file_path, format FROM books WHERE id = ?", (book_id,)
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Book not found")
    finally:
        await db.close()

    if row["format"] != "EPUB":
        raise HTTPException(400, "Not an EPUB")

    try:
        import ebooklib
        from ebooklib import epub

        book = epub.read_epub(row["file_path"])
        doc_items = [item for item in book.get_items() if item.get_type() == ebooklib.ITEM_DOCUMENT]
        chapters, first_content = _build_smart_toc(book, doc_items)

        return {
            "book_id": book_id,
            "chapters": chapters,
            "total": len(chapters),
            "first_content_index": first_content,
        }
    except Exception as e:
        logger.error(f"TOC extraction failed for book {book_id}: {e}")
        raise HTTPException(500, str(e))


@router.get("/{book_id}")
async def get_book(book_id: int):
    """Get details for a single book."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM books WHERE id = ?", (book_id,))
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Book not found")
        return row_to_dict(row)
    finally:
        await db.close()


# ===========================================================================
# PER-ACCOUNT BOOK DATA
# ===========================================================================

async def _ensure_account_book(db, account_id: int, book_id: int):
    """Ensure account and book exist; create book_account_data row if needed."""
    cursor = await db.execute("SELECT id FROM accounts WHERE id = ?", (account_id,))
    if not await cursor.fetchone():
        raise HTTPException(404, "Account not found")
    cursor = await db.execute("SELECT id FROM books WHERE id = ?", (book_id,))
    if not await cursor.fetchone():
        raise HTTPException(404, "Book not found")
    await db.execute(
        "INSERT OR IGNORE INTO book_account_data (account_id, book_id) VALUES (?, ?)",
        (account_id, book_id),
    )


@router.put("/accounts/{account_id}/books/{book_id}/progress")
async def update_reading_progress(account_id: int, book_id: int, data: ReadingProgressUpdate):
    """Save reading position (progress 0-1, optional page number)."""
    db = await get_db()
    try:
        await _ensure_account_book(db, account_id, book_id)

        now = datetime.utcnow().isoformat()

        # Check if this is a new start
        cursor = await db.execute(
            "SELECT started_at, reading_progress FROM book_account_data "
            "WHERE account_id = ? AND book_id = ?",
            (account_id, book_id),
        )
        row = await cursor.fetchone()
        started_at_clause = ""
        extra_params = []
        if row and not row["started_at"]:
            started_at_clause = ", started_at = ?"
            extra_params = [now]

        # Mark as finished if progress >= 0.95
        finished_clause = ""
        finished_params = []
        if data.progress >= 0.95:
            finished_clause = ", finished = 1, finished_at = ?"
            finished_params = [now]

        params = [data.progress] + ([data.current_page] if data.current_page is not None else [])
        page_clause = ", current_page = ?" if data.current_page is not None else ""

        await db.execute(
            f"""UPDATE book_account_data SET
                reading_progress = ?{page_clause}{started_at_clause}{finished_clause}
                WHERE account_id = ? AND book_id = ?""",
            [data.progress]
            + ([data.current_page] if data.current_page is not None else [])
            + extra_params
            + finished_params
            + [account_id, book_id],
        )
        await db.commit()

        return {
            "account_id": account_id,
            "book_id": book_id,
            "progress": data.progress,
            "current_page": data.current_page,
        }
    finally:
        await db.close()


@router.get("/accounts/{account_id}/books/currently-reading")
async def currently_reading(account_id: int):
    """Get books with partial reading progress."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT id FROM accounts WHERE id = ?", (account_id,))
        if not await cursor.fetchone():
            raise HTTPException(404, "Account not found")

        cursor = await db.execute(
            """SELECT b.*, bad.reading_progress, bad.current_page, bad.favorite,
                      bad.finished, bad.started_at, bad.total_reading_time
               FROM book_account_data bad
               JOIN books b ON b.id = bad.book_id
               WHERE bad.account_id = ? AND bad.reading_progress > 0 AND bad.finished = 0
               ORDER BY bad.started_at DESC
               LIMIT 50""",
            (account_id,),
        )
        rows = await cursor.fetchall()
        return {"items": [row_to_dict(r) for r in rows]}
    finally:
        await db.close()


@router.get("/accounts/{account_id}/books/finished")
async def finished_books(account_id: int):
    """Get completed books."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT id FROM accounts WHERE id = ?", (account_id,))
        if not await cursor.fetchone():
            raise HTTPException(404, "Account not found")

        cursor = await db.execute(
            """SELECT b.*, bad.reading_progress, bad.current_page, bad.favorite,
                      bad.finished, bad.finished_at, bad.total_reading_time
               FROM book_account_data bad
               JOIN books b ON b.id = bad.book_id
               WHERE bad.account_id = ? AND bad.finished = 1
               ORDER BY bad.finished_at DESC""",
            (account_id,),
        )
        rows = await cursor.fetchall()
        return {"items": [row_to_dict(r) for r in rows]}
    finally:
        await db.close()


@router.post("/accounts/{account_id}/books/{book_id}/favorite")
async def toggle_book_favorite(account_id: int, book_id: int):
    """Toggle favorite status for a book."""
    db = await get_db()
    try:
        await _ensure_account_book(db, account_id, book_id)
        cursor = await db.execute(
            "SELECT favorite FROM book_account_data WHERE account_id = ? AND book_id = ?",
            (account_id, book_id),
        )
        current = (await cursor.fetchone())["favorite"]
        new_val = 0 if current else 1
        await db.execute(
            "UPDATE book_account_data SET favorite = ? WHERE account_id = ? AND book_id = ?",
            (new_val, account_id, book_id),
        )
        await db.commit()
        return {"account_id": account_id, "book_id": book_id, "favorite": bool(new_val)}
    finally:
        await db.close()


@router.post("/accounts/{account_id}/books/{book_id}/bookmarks")
async def add_bookmark(account_id: int, book_id: int, data: BookmarkCreate):
    """Add a bookmark at a page with optional note."""
    db = await get_db()
    try:
        await _ensure_account_book(db, account_id, book_id)
        cursor = await db.execute(
            "INSERT INTO book_bookmarks (account_id, book_id, page, note) VALUES (?, ?, ?, ?)",
            (account_id, book_id, data.page, data.note),
        )
        await db.commit()
        return {
            "id": cursor.lastrowid,
            "account_id": account_id,
            "book_id": book_id,
            "page": data.page,
            "note": data.note,
        }
    finally:
        await db.close()


@router.get("/accounts/{account_id}/books/{book_id}/bookmarks")
async def list_bookmarks(account_id: int, book_id: int):
    """List bookmarks for a book."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM book_bookmarks WHERE account_id = ? AND book_id = ? ORDER BY page ASC",
            (account_id, book_id),
        )
        rows = await cursor.fetchall()
        return {"bookmarks": [row_to_dict(r) for r in rows]}
    finally:
        await db.close()


@router.delete("/accounts/{account_id}/books/{book_id}/bookmarks/{bookmark_id}")
async def delete_bookmark(account_id: int, book_id: int, bookmark_id: int):
    """Delete a bookmark."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id FROM book_bookmarks WHERE id = ? AND account_id = ? AND book_id = ?",
            (bookmark_id, account_id, book_id),
        )
        if not await cursor.fetchone():
            raise HTTPException(404, "Bookmark not found")
        await db.execute("DELETE FROM book_bookmarks WHERE id = ?", (bookmark_id,))
        await db.commit()
        return {"deleted": bookmark_id}
    finally:
        await db.close()


@router.get("/accounts/{account_id}/books/stats")
async def account_book_stats(account_id: int):
    """Per-user reading stats."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT id, name FROM accounts WHERE id = ?", (account_id,))
        acct = await cursor.fetchone()
        if not acct:
            raise HTTPException(404, "Account not found")

        stats = {"account_id": account_id, "account_name": acct["name"]}

        cursor = await db.execute(
            "SELECT COUNT(*) as c FROM book_account_data WHERE account_id = ? AND finished = 1",
            (account_id,),
        )
        stats["books_finished"] = (await cursor.fetchone())["c"]

        cursor = await db.execute(
            "SELECT COUNT(*) as c FROM book_account_data WHERE account_id = ? AND reading_progress > 0 AND finished = 0",
            (account_id,),
        )
        stats["books_in_progress"] = (await cursor.fetchone())["c"]

        cursor = await db.execute(
            "SELECT COUNT(*) as c FROM book_account_data WHERE account_id = ? AND favorite = 1",
            (account_id,),
        )
        stats["favorites_count"] = (await cursor.fetchone())["c"]

        cursor = await db.execute(
            "SELECT COALESCE(SUM(total_reading_time), 0) as t FROM book_account_data WHERE account_id = ?",
            (account_id,),
        )
        total_secs = (await cursor.fetchone())["t"]
        stats["total_reading_time_seconds"] = total_secs
        stats["total_reading_time_hours"] = round(total_secs / 3600, 1)

        # Total pages read (estimate from progress * page_count)
        cursor = await db.execute(
            """SELECT COALESCE(SUM(CAST(bad.reading_progress * b.page_count AS INTEGER)), 0) as p
               FROM book_account_data bad
               JOIN books b ON b.id = bad.book_id
               WHERE bad.account_id = ? AND b.page_count > 0""",
            (account_id,),
        )
        stats["pages_read"] = (await cursor.fetchone())["p"]

        cursor = await db.execute(
            "SELECT COUNT(*) as c FROM book_bookmarks WHERE account_id = ?",
            (account_id,),
        )
        stats["total_bookmarks"] = (await cursor.fetchone())["c"]

        return stats
    finally:
        await db.close()
