"""Book scanner — walks directories, extracts metadata, generates covers."""

import asyncio
import logging
import os
import re
import time
from pathlib import Path
from typing import Callable, Optional

from database import get_db

logger = logging.getLogger("cinemate.book_scanner")

BOOK_EXTENSIONS = {
    ".epub", ".pdf", ".mobi", ".azw3", ".fb2", ".djvu", ".cbz", ".cbr",
}

COVER_DIR = Path.home() / ".cinemate" / "book_covers"


class BookScanState:
    """Global book scan state — tracks progress for the status endpoint."""

    def __init__(self):
        self.scanning = False
        self.total_files = 0
        self.processed_files = 0
        self.current_file = ""
        self.new_items = 0
        self.errors = 0
        self.started_at: Optional[float] = None
        self.finished_at: Optional[float] = None

    def to_dict(self) -> dict:
        return {
            "scanning": self.scanning,
            "total_files": self.total_files,
            "processed_files": self.processed_files,
            "current_file": self.current_file,
            "new_items": self.new_items,
            "errors": self.errors,
            "progress_pct": round(
                (self.processed_files / self.total_files * 100) if self.total_files > 0 else 0, 1
            ),
            "started_at": self.started_at,
            "finished_at": self.finished_at,
        }


book_scan_state = BookScanState()


def ensure_cover_dir():
    """Create cover directory if needed."""
    COVER_DIR.mkdir(parents=True, exist_ok=True)


def find_book_files(root: str) -> list[str]:
    """Recursively find all book files under root."""
    books = []
    for dirpath, _dirnames, filenames in os.walk(root):
        for fname in filenames:
            if Path(fname).suffix.lower() in BOOK_EXTENSIONS:
                books.append(os.path.join(dirpath, fname))
    return sorted(books)


def parse_book_filename(filepath: str) -> dict:
    """Extract title and author from filename heuristics."""
    name = Path(filepath).stem
    ext = Path(filepath).suffix.lower().lstrip(".")

    # Try "Author - Title" pattern
    author = None
    title = name

    if " - " in name:
        parts = name.split(" - ", 1)
        author = parts[0].strip()
        title = parts[1].strip()
    elif " by " in name.lower():
        idx = name.lower().index(" by ")
        title = name[:idx].strip()
        author = name[idx + 4:].strip()

    # Clean up underscores/dots
    title = re.sub(r"[._]", " ", title)
    title = re.sub(r"\s+", " ", title).strip()
    if author:
        author = re.sub(r"[._]", " ", author)
        author = re.sub(r"\s+", " ", author).strip()

    # Try to extract year from parentheses
    year = None
    year_match = re.search(r"[\(\[\{]?((?:19|20)\d{2})[\)\]\}]?", title)
    if year_match:
        candidate = int(year_match.group(1))
        if 1800 <= candidate <= 2030:
            year = candidate
            title = title[:year_match.start()] + title[year_match.end():]
            title = title.strip(" -,()")

    return {
        "title": title or Path(filepath).stem,
        "author": author,
        "year": year,
        "format": ext.upper(),
    }


def extract_epub_metadata(filepath: str) -> dict:
    """Extract metadata from EPUB using ebooklib."""
    result = {}
    try:
        import ebooklib
        from ebooklib import epub

        book = epub.read_epub(filepath, options={"ignore_ncx": True})

        # Title
        titles = book.get_metadata("DC", "title")
        if titles:
            result["title"] = titles[0][0]

        # Author
        creators = book.get_metadata("DC", "creator")
        if creators:
            result["author"] = creators[0][0]

        # Language
        langs = book.get_metadata("DC", "language")
        if langs:
            result["language"] = langs[0][0]

        # Publisher
        publishers = book.get_metadata("DC", "publisher")
        if publishers:
            result["publisher"] = publishers[0][0]

        # Description
        descriptions = book.get_metadata("DC", "description")
        if descriptions:
            desc = descriptions[0][0]
            # Strip HTML tags from description
            desc = re.sub(r"<[^>]+>", "", desc)
            result["description"] = desc[:2000]  # Truncate

        # Cover image
        cover_image = None
        for item in book.get_items():
            if item.get_type() == ebooklib.ITEM_COVER:
                cover_image = item.get_content()
                break
        if not cover_image:
            # Try to find cover by name
            for item in book.get_items_of_type(ebooklib.ITEM_IMAGE):
                name = (item.get_name() or "").lower()
                if "cover" in name:
                    cover_image = item.get_content()
                    break
        if cover_image:
            result["cover_data"] = cover_image

    except Exception as e:
        logger.debug(f"EPUB metadata extraction failed for {filepath}: {e}")

    return result


def extract_pdf_metadata(filepath: str) -> dict:
    """Extract metadata from PDF using PyPDF2."""
    result = {}
    try:
        from PyPDF2 import PdfReader

        reader = PdfReader(filepath)

        # Page count
        result["page_count"] = len(reader.pages)

        # Metadata
        meta = reader.metadata
        if meta:
            if meta.title:
                result["title"] = meta.title
            if meta.author:
                result["author"] = meta.author

        # Extract first page as cover image using pdf2image or a simple approach
        try:
            import subprocess
            ensure_cover_dir()
            # Use sips/qlmanage on macOS for PDF thumbnail
            cover_path = str(COVER_DIR / f"_temp_pdf_cover.jpg")
            subprocess.run(
                ["qlmanage", "-t", "-s", "600", "-o", str(COVER_DIR), filepath],
                capture_output=True, timeout=30,
            )
            # qlmanage outputs as <filename>.png in the output dir
            expected = COVER_DIR / (Path(filepath).name + ".png")
            if expected.exists():
                result["cover_path_temp"] = str(expected)
        except Exception:
            pass

    except Exception as e:
        logger.debug(f"PDF metadata extraction failed for {filepath}: {e}")

    return result


def save_cover_image(book_id: int, data: bytes = None, source_path: str = None) -> Optional[str]:
    """Save cover image data to disk. Returns path or None."""
    ensure_cover_dir()
    out_path = str(COVER_DIR / f"{book_id}.jpg")

    if data:
        try:
            with open(out_path, "wb") as f:
                f.write(data)
            return out_path
        except Exception as e:
            logger.debug(f"Failed to save cover for book {book_id}: {e}")
            return None

    if source_path and os.path.exists(source_path):
        try:
            import shutil
            # If it's a PNG, just copy it (browsers/apps handle both)
            ext = Path(source_path).suffix.lower()
            final_path = str(COVER_DIR / f"{book_id}{ext}")
            shutil.move(source_path, final_path)
            return final_path
        except Exception as e:
            logger.debug(f"Failed to move cover for book {book_id}: {e}")
            return None

    return None


def extract_metadata(filepath: str) -> dict:
    """Extract metadata based on file format. Returns merged dict."""
    ext = Path(filepath).suffix.lower()
    filename_meta = parse_book_filename(filepath)

    format_meta = {}
    if ext == ".epub":
        format_meta = extract_epub_metadata(filepath)
    elif ext == ".pdf":
        format_meta = extract_pdf_metadata(filepath)

    # Merge: format-specific metadata overrides filename guesses
    merged = {
        "title": format_meta.get("title") or filename_meta.get("title") or Path(filepath).stem,
        "author": format_meta.get("author") or filename_meta.get("author"),
        "year": filename_meta.get("year"),
        "format": filename_meta.get("format", ext.lstrip(".").upper()),
        "language": format_meta.get("language"),
        "publisher": format_meta.get("publisher"),
        "description": format_meta.get("description"),
        "page_count": format_meta.get("page_count", 0),
        "cover_data": format_meta.get("cover_data"),
        "cover_path_temp": format_meta.get("cover_path_temp"),
    }
    return merged


async def scan_books_directory(path: str, ws_broadcast=None):
    """Scan a directory tree for books, insert new ones into DB."""
    global book_scan_state

    if book_scan_state.scanning:
        logger.warning("Book scan already in progress")
        return

    book_scan_state = BookScanState()
    book_scan_state.scanning = True
    book_scan_state.started_at = time.time()

    try:
        if not os.path.isdir(path):
            raise ValueError(f"Directory not found: {path}")

        logger.info(f"Scanning for books in: {path}")
        book_files = await asyncio.to_thread(find_book_files, path)
        book_scan_state.total_files = len(book_files)
        logger.info(f"Found {len(book_files)} book files")

        if ws_broadcast:
            await ws_broadcast({
                "type": "book_scan_started",
                "total_files": len(book_files),
                "path": path,
            })

        db = await get_db()
        try:
            for filepath in book_files:
                book_scan_state.current_file = os.path.basename(filepath)
                book_scan_state.processed_files += 1

                try:
                    # Check if already in DB
                    cursor = await db.execute(
                        "SELECT id FROM books WHERE file_path = ?", (filepath,)
                    )
                    existing = await cursor.fetchone()
                    if existing:
                        continue

                    # Extract metadata (in thread to avoid blocking)
                    meta = await asyncio.to_thread(extract_metadata, filepath)
                    file_size = os.path.getsize(filepath)

                    cursor = await db.execute(
                        """INSERT INTO books
                           (title, author, genre, publisher, language, description,
                            page_count, format, file_path, file_size, year, date_added)
                           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))""",
                        (
                            meta["title"],
                            meta["author"],
                            None,  # genre — not reliably extractable
                            meta["publisher"],
                            meta["language"],
                            meta["description"],
                            meta["page_count"],
                            meta["format"],
                            filepath,
                            file_size,
                            meta["year"],
                        ),
                    )
                    book_id = cursor.lastrowid
                    await db.commit()
                    book_scan_state.new_items += 1

                    # Save cover image
                    cover_path = None
                    if meta.get("cover_data"):
                        cover_path = await asyncio.to_thread(
                            save_cover_image, book_id, data=meta["cover_data"]
                        )
                    elif meta.get("cover_path_temp"):
                        cover_path = await asyncio.to_thread(
                            save_cover_image, book_id, source_path=meta["cover_path_temp"]
                        )

                    if cover_path:
                        await db.execute(
                            "UPDATE books SET cover_path = ? WHERE id = ?",
                            (cover_path, book_id),
                        )
                        await db.commit()

                    if ws_broadcast:
                        await ws_broadcast({
                            "type": "book_added",
                            "book_id": book_id,
                            "title": meta["title"],
                        })

                except Exception as e:
                    book_scan_state.errors += 1
                    logger.error(f"Error processing book {filepath}: {e}")

                # Broadcast progress periodically
                if ws_broadcast and book_scan_state.processed_files % 5 == 0:
                    await ws_broadcast({
                        "type": "book_scan_progress",
                        **book_scan_state.to_dict(),
                    })

        finally:
            await db.close()

    except Exception as e:
        logger.error(f"Book scan failed: {e}")
        book_scan_state.errors += 1
    finally:
        book_scan_state.scanning = False
        book_scan_state.finished_at = time.time()
        book_scan_state.current_file = ""

        if ws_broadcast:
            await ws_broadcast({
                "type": "book_scan_complete",
                **book_scan_state.to_dict(),
            })

        logger.info(
            f"Book scan complete: {book_scan_state.new_items} new, "
            f"{book_scan_state.errors} errors, "
            f"{book_scan_state.processed_files}/{book_scan_state.total_files} processed"
        )
