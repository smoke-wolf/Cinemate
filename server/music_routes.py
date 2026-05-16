"""Music routes — FastAPI router for music library, streaming, playlists, and per-account features."""

import asyncio
import array
import logging
import math
import os
import struct
import wave
from datetime import datetime
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel

from database import get_db, ALBUM_ART_DIR, ARTIST_IMG_DIR
from music_scanner import scan_music_directory, music_scan_state
from spotify_scraper import SpotifyScraper, enrich_library_genres

logger = logging.getLogger("cinemate.music")

router = APIRouter()

# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------


class MusicScanRequest(BaseModel):
    path: str


class PlaylistCreate(BaseModel):
    name: str
    description: Optional[str] = None


class PlaylistUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None


class PlaylistAddTracks(BaseModel):
    track_ids: list[int]


class QueueUpdate(BaseModel):
    track_ids: list[int]


class PlayHistoryLog(BaseModel):
    track_id: int
    duration_listened: float = 0.0


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------


def row_to_dict(row) -> dict:
    if row is None:
        return {}
    return dict(row)


async def _ensure_account(db, account_id: int):
    """Raise 404 if account doesn't exist."""
    cursor = await db.execute("SELECT id FROM accounts WHERE id = ?", (account_id,))
    if not await cursor.fetchone():
        raise HTTPException(404, "Account not found")


# ===========================================================================
# LIBRARY ENDPOINTS
# ===========================================================================


_TRACK_SORT_COLUMNS = {
    "title": "title",
    "artist": "artist",
    "album": "album",
    "year": "year",
    "date_added": "date_added",
    "duration": "duration",
    "track_number": "track_number",
}

_ALBUM_SORT_COLUMNS = {
    "name": "name",
    "artist": "artist",
    "year": "year",
    "date_added": "date_added",
    "track_count": "track_count",
}

_ORDER_DIRECTIONS = {"asc": "ASC", "desc": "DESC"}


@router.get("/api/music/tracks")
async def list_tracks(
    search: Optional[str] = None,
    sort: str = Query(
        "date_added",
        pattern="^(title|artist|album|year|date_added|duration|track_number)$",
    ),
    order: str = Query("asc", pattern="^(asc|desc)$"),
    artist: Optional[str] = None,
    album: Optional[str] = None,
    album_id: Optional[int] = None,
    genre: Optional[str] = None,
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
):
    """List all music tracks with filtering, sorting, pagination."""
    # Whitelist-based SQL injection prevention — never interpolate user input
    safe_sort = _TRACK_SORT_COLUMNS.get(sort)
    if not safe_sort:
        raise HTTPException(400, f"Invalid sort column: {sort}")
    safe_order = _ORDER_DIRECTIONS.get(order)
    if not safe_order:
        raise HTTPException(400, f"Invalid order direction: {order}")

    db = await get_db()
    try:
        conditions = []
        params = []

        if search:
            conditions.append("(title LIKE ? OR artist LIKE ? OR album LIKE ?)")
            params.extend([f"%{search}%"] * 3)
        if artist:
            conditions.append("artist LIKE ?")
            params.append(f"%{artist}%")
        if album:
            conditions.append("album LIKE ?")
            params.append(f"%{album}%")
        if album_id is not None:
            conditions.append("album_id = ?")
            params.append(album_id)
        if genre:
            conditions.append("genre LIKE ?")
            params.append(f"%{genre}%")

        where = " WHERE " + " AND ".join(conditions) if conditions else ""
        order_clause = f" ORDER BY {safe_sort} {safe_order}"

        cursor = await db.execute(
            f"SELECT COUNT(*) as cnt FROM music_tracks{where}", params
        )
        total = (await cursor.fetchone())["cnt"]

        cursor = await db.execute(
            f"SELECT * FROM music_tracks{where}{order_clause} LIMIT ? OFFSET ?",
            params + [limit, offset],
        )
        rows = await cursor.fetchall()
        return {
            "items": [row_to_dict(r) for r in rows],
            "total": total,
            "limit": limit,
            "offset": offset,
        }
    finally:
        await db.close()


@router.get("/api/music/tracks/{track_id}")
async def get_track(track_id: int):
    """Get a single track's details."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM music_tracks WHERE id = ?", (track_id,)
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Track not found")
        return row_to_dict(row)
    finally:
        await db.close()


@router.get("/api/music/artists")
async def list_artists(
    search: Optional[str] = None,
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
):
    """List all artists with track and album counts."""
    db = await get_db()
    try:
        conditions = []
        params = []
        if search:
            conditions.append("artist LIKE ?")
            params.append(f"%{search}%")

        where = " WHERE " + " AND ".join(conditions) if conditions else ""

        cursor = await db.execute(
            f"""SELECT artist,
                       COUNT(*) as track_count,
                       COUNT(DISTINCT album) as album_count,
                       COALESCE(SUM(duration), 0) as total_duration
                FROM music_tracks{where}
                GROUP BY artist
                ORDER BY artist
                LIMIT ? OFFSET ?""",
            params + [limit, offset],
        )
        rows = await cursor.fetchall()

        cursor = await db.execute(
            f"SELECT COUNT(DISTINCT artist) as cnt FROM music_tracks{where}", params
        )
        total = (await cursor.fetchone())["cnt"]

        return {
            "items": [row_to_dict(r) for r in rows],
            "total": total,
            "limit": limit,
            "offset": offset,
        }
    finally:
        await db.close()


@router.get("/api/music/artists/{name}")
async def get_artist(name: str):
    """Artist detail with albums and tracks."""
    db = await get_db()
    try:
        # Get all tracks by this artist
        cursor = await db.execute(
            "SELECT * FROM music_tracks WHERE artist = ? ORDER BY album, disc_number, track_number",
            (name,),
        )
        tracks = [row_to_dict(r) for r in await cursor.fetchall()]
        if not tracks:
            raise HTTPException(404, "Artist not found")

        # Group by album
        albums: dict = {}
        for t in tracks:
            aname = t.get("album") or "Unknown Album"
            if aname not in albums:
                albums[aname] = {
                    "name": aname,
                    "album_id": t.get("album_id"),
                    "year": t.get("year"),
                    "tracks": [],
                }
            albums[aname]["tracks"].append(t)

        return {
            "artist": name,
            "track_count": len(tracks),
            "album_count": len(albums),
            "total_duration": sum(t.get("duration", 0) for t in tracks),
            "albums": list(albums.values()),
        }
    finally:
        await db.close()


# ---------------------------------------------------------------------------
# Artist enrichment state
# ---------------------------------------------------------------------------

_enrichment_running = False
_genre_classify_running = False


@router.get("/api/music/artists/{name}/profile")
async def get_artist_profile(name: str):
    """Return enriched artist profile, triggering enrichment if stale or missing."""
    db = await get_db()
    try:
        # Check for cached profile in music_artists table
        cursor = await db.execute(
            "SELECT * FROM music_artists WHERE name = ?", (name,)
        )
        artist_row = await cursor.fetchone()

        profile = None
        needs_enrichment = True

        if artist_row:
            profile = row_to_dict(artist_row)
            # Parse genres from comma-separated string to list
            if profile.get("genres"):
                profile["genres"] = [
                    g.strip() for g in profile["genres"].split(",")
                ]
            else:
                profile["genres"] = []
            # Check staleness — enriched_at older than 7 days
            if profile.get("enriched_at"):
                enriched_dt = datetime.fromisoformat(profile["enriched_at"])
                age_days = (datetime.utcnow() - enriched_dt).days
                if age_days < 7:
                    needs_enrichment = False

        if needs_enrichment:
            scraper = SpotifyScraper()
            enriched = await scraper.enrich_artist(name)
            if enriched:
                genres_str = enriched.get("genres") or ""
                now = datetime.utcnow().isoformat()
                if artist_row:
                    await db.execute(
                        """UPDATE music_artists
                           SET bio = ?, image_url = ?, genres = ?,
                               spotify_id = ?, popularity = ?, followers = ?,
                               wikipedia_url = ?, enriched_at = ?
                           WHERE name = ?""",
                        (
                            enriched.get("bio"),
                            enriched.get("image_url"),
                            genres_str,
                            enriched.get("spotify_id"),
                            enriched.get("popularity"),
                            enriched.get("followers"),
                            enriched.get("wikipedia_url"),
                            now,
                            name,
                        ),
                    )
                else:
                    await db.execute(
                        """INSERT INTO music_artists
                           (name, bio, image_url, genres, spotify_id,
                            popularity, followers, wikipedia_url, enriched_at)
                           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                        (
                            name,
                            enriched.get("bio"),
                            enriched.get("image_url"),
                            genres_str,
                            enriched.get("spotify_id"),
                            enriched.get("popularity"),
                            enriched.get("followers"),
                            enriched.get("wikipedia_url"),
                            now,
                        ),
                    )
                await db.commit()
                genres_list = [g.strip() for g in genres_str.split(",") if g.strip()] if genres_str else []
                profile = {
                    "name": name,
                    "bio": enriched.get("bio"),
                    "image_url": enriched.get("image_url"),
                    "genres": genres_list,
                    "spotify_id": enriched.get("spotify_id"),
                    "popularity": enriched.get("popularity"),
                    "followers": enriched.get("followers"),
                    "wikipedia_url": enriched.get("wikipedia_url"),
                }
            elif not profile:
                # No cached data and enrichment returned nothing —
                # verify the artist at least exists in the library
                cursor = await db.execute(
                    "SELECT COUNT(*) as cnt FROM music_tracks WHERE artist = ?",
                    (name,),
                )
                if (await cursor.fetchone())["cnt"] == 0:
                    raise HTTPException(404, "Artist not found")
                profile = {"name": name, "genres": []}

        # Aggregate track/album counts from library
        cursor = await db.execute(
            """SELECT COUNT(*) as track_count,
                      COUNT(DISTINCT album) as album_count
               FROM music_tracks WHERE artist = ?""",
            (name,),
        )
        counts = row_to_dict(await cursor.fetchone())
        profile["track_count"] = counts["track_count"]
        profile["album_count"] = counts["album_count"]

        return profile
    finally:
        await db.close()


@router.post("/api/music/artists/enrich-all")
async def enrich_all_artists():
    """Trigger background enrichment of all artists in the library."""
    global _enrichment_running
    if _enrichment_running:
        raise HTTPException(409, "Artist enrichment already in progress")

    async def _enrich_all_bg():
        global _enrichment_running
        _enrichment_running = True
        try:
            db = await get_db()
            try:
                cursor = await db.execute(
                    "SELECT DISTINCT artist FROM music_tracks ORDER BY artist"
                )
                rows = await cursor.fetchall()
            finally:
                await db.close()

            scraper = SpotifyScraper()
            enriched_count = 0
            for row in rows:
                artist_name = row["artist"]
                try:
                    enriched = await scraper.enrich_artist(artist_name)
                    if enriched:
                        db = await get_db()
                        try:
                            genres_str = enriched.get("genres") or ""
                            now = datetime.utcnow().isoformat()
                            await db.execute(
                                """INSERT INTO music_artists
                                   (name, bio, image_url, genres, spotify_id,
                                    popularity, followers, wikipedia_url, enriched_at)
                                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                                   ON CONFLICT(name) DO UPDATE SET
                                    bio = excluded.bio,
                                    image_url = excluded.image_url,
                                    genres = excluded.genres,
                                    spotify_id = excluded.spotify_id,
                                    popularity = excluded.popularity,
                                    followers = excluded.followers,
                                    wikipedia_url = excluded.wikipedia_url,
                                    enriched_at = excluded.enriched_at""",
                                (
                                    artist_name,
                                    enriched.get("bio"),
                                    enriched.get("image_url"),
                                    genres_str,
                                    enriched.get("spotify_id"),
                                    enriched.get("popularity"),
                                    enriched.get("followers"),
                                    enriched.get("wikipedia_url"),
                                    now,
                                ),
                            )
                            await db.commit()
                            enriched_count += 1
                        finally:
                            await db.close()
                    # Rate limit — avoid hammering Spotify
                    await asyncio.sleep(1.0)
                except Exception:
                    logger.exception("Failed to enrich artist: %s", artist_name)
            logger.info(
                "Artist enrichment complete: %d/%d enriched",
                enriched_count,
                len(rows),
            )
        except Exception:
            logger.exception("Background artist enrichment failed")
        finally:
            _enrichment_running = False

    asyncio.create_task(_enrich_all_bg())
    return {"status": "enrichment_started"}


@router.post("/api/music/genres/classify")
async def classify_genres():
    """Trigger background genre backfill for tracks with NULL genre."""
    global _genre_classify_running
    if _genre_classify_running:
        raise HTTPException(409, "Genre classification already in progress")

    async def _classify_genres_bg():
        global _genre_classify_running
        _genre_classify_running = True
        try:
            db = await get_db()
            try:
                result = await enrich_library_genres(db)
                await db.commit()
                logger.info("Genre classification complete: %s", result)
            finally:
                await db.close()
        except Exception:
            logger.exception("Background genre classification failed")
        finally:
            _genre_classify_running = False

    asyncio.create_task(_classify_genres_bg())
    return {"status": "genre_classification_started"}


@router.get("/api/music/artists/{name}/image")
async def get_artist_image(name: str):
    """Serve artist image from disk, downloading from remote URL if needed.

    Priority:
    1. Cached artist image on disk (music_artists.image_path).
    2. Remote artist image URL (music_artists.image_url) — downloaded and cached on first request.
    3. Album art from music_albums.art_path for any album by this artist.
    4. Album art file on disk at ALBUM_ART_DIR/{album_id}.jpg (handles DB art_path being NULL).
    Returns 404 if no image source is available.
    """
    import urllib.parse

    decoded_name = urllib.parse.unquote(name)

    db = await get_db()
    try:
        # 1. Try dedicated artist image already on disk
        cursor = await db.execute(
            "SELECT image_path, image_url FROM music_artists WHERE name = ?", (decoded_name,)
        )
        row = await cursor.fetchone()
        if row and row["image_path"]:
            image_path = Path(row["image_path"])
            if not image_path.is_absolute():
                image_path = ARTIST_IMG_DIR / image_path
            if image_path.is_file():
                return FileResponse(str(image_path), media_type="image/jpeg")

        # 2. Try downloading from remote image_url (Spotify CDN etc.)
        if row and row["image_url"]:
            downloaded_path = await _download_artist_image(
                decoded_name, row["image_url"], db
            )
            if downloaded_path and downloaded_path.is_file():
                return FileResponse(str(downloaded_path), media_type="image/jpeg")

        # 3. Fall back to album art from any album by this artist (DB art_path)
        cursor = await db.execute(
            """SELECT id, art_path FROM music_albums
               WHERE (artist = ? OR album_artist = ?)
               ORDER BY
                   CASE WHEN art_path IS NOT NULL AND art_path != '' THEN 0 ELSE 1 END,
                   year DESC, name
               LIMIT 1""",
            (decoded_name, decoded_name),
        )
        album_row = await cursor.fetchone()
        if album_row:
            # 3a. Use art_path from DB if available
            if album_row["art_path"]:
                art_path = Path(album_row["art_path"])
                if art_path.is_file():
                    return FileResponse(str(art_path), media_type="image/jpeg")
            # 3b. Check ALBUM_ART_DIR/{album_id}.jpg directly (art_path may be NULL
            #     even though the file exists on disk)
            fallback_art = ALBUM_ART_DIR / f"{album_row['id']}.jpg"
            if fallback_art.is_file():
                return FileResponse(str(fallback_art), media_type="image/jpeg")

        # 4. Check ALL albums by this artist for art files on disk
        cursor = await db.execute(
            """SELECT id FROM music_albums
               WHERE (artist = ? OR album_artist = ?)
               ORDER BY year DESC, name""",
            (decoded_name, decoded_name),
        )
        all_albums = await cursor.fetchall()
        for album in all_albums:
            fallback_art = ALBUM_ART_DIR / f"{album['id']}.jpg"
            if fallback_art.is_file():
                return FileResponse(str(fallback_art), media_type="image/jpeg")

        raise HTTPException(404, "Artist image not found")
    finally:
        await db.close()


async def _download_artist_image(
    artist_name: str, image_url: str, db
) -> Optional[Path]:
    """Download an artist image from a remote URL and cache it locally.

    Saves to ARTIST_IMG_DIR/{sanitized_name}.jpg and updates music_artists.image_path.
    Returns the Path on success, or None on failure.
    """
    import aiohttp
    import re

    try:
        ARTIST_IMG_DIR.mkdir(parents=True, exist_ok=True)
        # Sanitize artist name for filename
        safe_name = re.sub(r'[^\w\s-]', '', artist_name).strip().replace(' ', '_')
        if not safe_name:
            safe_name = "artist"
        out_path = ARTIST_IMG_DIR / f"{safe_name}.jpg"

        # Don't re-download if file already exists
        if out_path.is_file():
            # Update DB so next request hits the fast path
            await db.execute(
                "UPDATE music_artists SET image_path = ? WHERE name = ?",
                (str(out_path), artist_name),
            )
            await db.commit()
            return out_path

        async with aiohttp.ClientSession() as session:
            async with session.get(
                image_url,
                timeout=aiohttp.ClientTimeout(total=15),
                headers={"User-Agent": "CinemateApp/1.0"},
            ) as resp:
                if resp.status != 200:
                    logger.warning(
                        "Failed to download artist image for '%s': HTTP %d",
                        artist_name, resp.status,
                    )
                    return None
                data = await resp.read()

        if len(data) < 100:
            logger.warning("Artist image too small for '%s' (%d bytes)", artist_name, len(data))
            return None

        # Try to convert to JPEG via PIL, fall back to raw bytes
        try:
            from PIL import Image
            import io
            img = Image.open(io.BytesIO(data))
            img = img.convert("RGB")
            img.save(str(out_path), "JPEG", quality=85)
        except ImportError:
            with open(out_path, "wb") as f:
                f.write(data)

        # Update DB with local path
        await db.execute(
            "UPDATE music_artists SET image_path = ? WHERE name = ?",
            (str(out_path), artist_name),
        )
        await db.commit()
        logger.info("Downloaded artist image for '%s' -> %s", artist_name, out_path)
        return out_path

    except Exception as e:
        logger.warning("Error downloading artist image for '%s': %s", artist_name, e)
        return None


@router.get("/api/music/albums")
async def list_albums(
    search: Optional[str] = None,
    artist: Optional[str] = None,
    year: Optional[int] = None,
    sort: str = Query("name", pattern="^(name|artist|year|date_added|track_count)$"),
    order: str = Query("asc", pattern="^(asc|desc)$"),
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
):
    """List all albums."""
    # Whitelist-based SQL injection prevention
    safe_sort = _ALBUM_SORT_COLUMNS.get(sort)
    if not safe_sort:
        raise HTTPException(400, f"Invalid sort column: {sort}")
    safe_order = _ORDER_DIRECTIONS.get(order)
    if not safe_order:
        raise HTTPException(400, f"Invalid order direction: {order}")

    db = await get_db()
    try:
        conditions = []
        params = []
        if search:
            conditions.append("(name LIKE ? OR artist LIKE ?)")
            params.extend([f"%{search}%"] * 2)
        if artist:
            conditions.append("artist LIKE ?")
            params.append(f"%{artist}%")
        if year:
            conditions.append("year = ?")
            params.append(year)

        where = " WHERE " + " AND ".join(conditions) if conditions else ""
        order_clause = f" ORDER BY {safe_sort} {safe_order}"

        cursor = await db.execute(
            f"SELECT COUNT(*) as cnt FROM music_albums{where}", params
        )
        total = (await cursor.fetchone())["cnt"]

        cursor = await db.execute(
            f"SELECT * FROM music_albums{where}{order_clause} LIMIT ? OFFSET ?",
            params + [limit, offset],
        )
        rows = await cursor.fetchall()
        return {
            "items": [row_to_dict(r) for r in rows],
            "total": total,
            "limit": limit,
            "offset": offset,
        }
    finally:
        await db.close()


@router.get("/api/music/albums/{album_id}")
async def get_album(album_id: int):
    """Album detail with all tracks in order."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM music_albums WHERE id = ?", (album_id,)
        )
        album = await cursor.fetchone()
        if not album:
            raise HTTPException(404, "Album not found")

        cursor = await db.execute(
            "SELECT * FROM music_tracks WHERE album_id = ? ORDER BY disc_number, track_number",
            (album_id,),
        )
        tracks = [row_to_dict(r) for r in await cursor.fetchall()]

        result = row_to_dict(album)
        result["tracks"] = tracks
        return result
    finally:
        await db.close()


@router.get("/api/music/genres")
async def list_genres():
    """Genre list with counts."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT genre, COUNT(*) as count FROM music_tracks "
            "WHERE genre IS NOT NULL AND genre != '' "
            "GROUP BY genre ORDER BY count DESC"
        )
        rows = await cursor.fetchall()
        return {"genres": [row_to_dict(r) for r in rows]}
    finally:
        await db.close()


@router.post("/api/music/scan")
async def start_music_scan(req: MusicScanRequest):
    """Trigger a music directory scan in the background."""
    if not os.path.isdir(req.path):
        raise HTTPException(400, f"Directory not found: {req.path}")
    if music_scan_state.scanning:
        raise HTTPException(409, "Music scan already in progress")

    # Import ws_manager lazily to avoid circular imports
    from main import ws_manager

    asyncio.create_task(
        scan_music_directory(req.path, ws_broadcast=ws_manager.broadcast)
    )
    return {"status": "music_scan_started", "path": req.path}


@router.get("/api/music/scan/status")
async def get_music_scan_status():
    """Get current music scan progress."""
    return music_scan_state.to_dict()


@router.get("/api/music/stats")
async def music_stats():
    """Library-wide music statistics."""
    db = await get_db()
    try:
        stats = {}

        cursor = await db.execute("SELECT COUNT(*) as c FROM music_tracks")
        stats["total_tracks"] = (await cursor.fetchone())["c"]

        cursor = await db.execute("SELECT COUNT(DISTINCT artist) as c FROM music_tracks")
        stats["total_artists"] = (await cursor.fetchone())["c"]

        cursor = await db.execute("SELECT COUNT(*) as c FROM music_albums")
        stats["total_albums"] = (await cursor.fetchone())["c"]

        cursor = await db.execute(
            "SELECT COALESCE(SUM(duration), 0) as d FROM music_tracks"
        )
        total_sec = (await cursor.fetchone())["d"]
        stats["total_duration_seconds"] = total_sec
        stats["total_duration_hours"] = round(total_sec / 3600, 1)

        cursor = await db.execute(
            "SELECT COALESCE(SUM(file_size), 0) as s FROM music_tracks"
        )
        total_bytes = (await cursor.fetchone())["s"]
        stats["total_size_bytes"] = total_bytes
        stats["total_size_gb"] = round(total_bytes / (1024**3), 2)

        cursor = await db.execute(
            "SELECT format, COUNT(*) as count FROM music_tracks "
            "GROUP BY format ORDER BY count DESC"
        )
        stats["format_breakdown"] = [
            row_to_dict(r) for r in await cursor.fetchall()
        ]

        return stats
    finally:
        await db.close()


# ===========================================================================
# STREAMING ENDPOINTS
# ===========================================================================


@router.get("/api/music/stream/{track_id}")
async def stream_audio(track_id: int, request: Request):
    """Stream an audio file with HTTP Range support."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT file_path, format FROM music_tracks WHERE id = ?", (track_id,)
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Track not found")
    finally:
        await db.close()

    file_path = row["file_path"]
    if not os.path.exists(file_path):
        raise HTTPException(404, f"Audio file not found on disk: {file_path}")

    file_size = os.path.getsize(file_path)
    ext = Path(file_path).suffix.lower()
    content_types = {
        ".mp3": "audio/mpeg",
        ".flac": "audio/flac",
        ".aac": "audio/aac",
        ".m4a": "audio/mp4",
        ".wav": "audio/wav",
        ".ogg": "audio/ogg",
        ".wma": "audio/x-ms-wma",
        ".aiff": "audio/aiff",
        ".opus": "audio/opus",
        ".alac": "audio/mp4",
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


LRC_DIR = os.path.expanduser("~/lyric-matcher/output")


@router.get("/api/music/lyrics/{track_id}")
async def get_lyrics(track_id: int):
    """Return parsed LRC lyrics for a track."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT artist, title FROM music_tracks WHERE id = ?", (track_id,)
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Track not found")
    finally:
        await db.close()

    safe_name = f"{row['artist']} - {row['title']}".replace("/", "-")
    lrc_path = os.path.join(LRC_DIR, f"{safe_name}.lrc")

    if not os.path.exists(lrc_path):
        return {"has_lyrics": False, "lines": []}

    lines = []
    import re
    pattern = re.compile(r"\[(\d{2}):(\d{2})\.(\d{2})\](.*)")
    with open(lrc_path, "r", encoding="utf-8") as f:
        for raw_line in f:
            m = pattern.match(raw_line.strip())
            if not m:
                continue
            time_s = int(m.group(1)) * 60 + int(m.group(2)) + int(m.group(3)) / 100.0
            text = m.group(4).strip()
            if text:
                lines.append({"time": round(time_s, 2), "text": text})

    return {"has_lyrics": len(lines) > 0, "lines": lines}


@router.get("/api/music/art/{album_id}")
async def serve_album_art(album_id: int):
    """Serve album artwork."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT art_path FROM music_albums WHERE id = ?", (album_id,)
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Album not found")
    finally:
        await db.close()

    art_path = row["art_path"]
    if not art_path or not os.path.exists(art_path):
        raise HTTPException(404, "Album art not available")

    return FileResponse(art_path, media_type="image/jpeg")


@router.get("/api/music/waveform/{track_id}")
async def get_waveform(track_id: int, points: int = Query(200, ge=50, le=2000)):
    """Generate/serve waveform amplitude data for visualization.

    Returns an array of normalized amplitude values (0.0-1.0).
    Uses ffmpeg to decode to raw PCM, then samples peaks.
    """
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT file_path FROM music_tracks WHERE id = ?", (track_id,)
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Track not found")
    finally:
        await db.close()

    file_path = row["file_path"]
    if not os.path.exists(file_path):
        raise HTTPException(404, "Audio file not found on disk")

    try:
        waveform = await asyncio.to_thread(_generate_waveform, file_path, points)
        return {"track_id": track_id, "points": points, "waveform": waveform}
    except Exception as e:
        logger.error(f"Waveform generation error: {e}")
        raise HTTPException(500, "Failed to generate waveform")


def _generate_waveform(file_path: str, num_points: int) -> list[float]:
    """Decode audio to raw PCM via ffmpeg and compute amplitude peaks."""
    import subprocess

    result = subprocess.run(
        [
            "ffmpeg",
            "-i", file_path,
            "-ac", "1",          # mono
            "-ar", "8000",       # 8kHz sample rate (enough for waveform)
            "-f", "s16le",       # signed 16-bit little-endian PCM
            "-v", "quiet",
            "-",
        ],
        capture_output=True,
        timeout=60,
    )
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg decode failed for {file_path}")

    raw = result.stdout
    if len(raw) < 4:
        return [0.0] * num_points

    # Parse samples
    num_samples = len(raw) // 2
    samples = struct.unpack(f"<{num_samples}h", raw[:num_samples * 2])

    # Divide into bins and take peak amplitude per bin
    samples_per_bin = max(1, num_samples // num_points)
    peaks = []
    for i in range(num_points):
        start = i * samples_per_bin
        end = min(start + samples_per_bin, num_samples)
        if start >= num_samples:
            peaks.append(0.0)
        else:
            chunk = samples[start:end]
            peak = max(abs(s) for s in chunk) if chunk else 0
            peaks.append(peak / 32768.0)  # normalize to 0.0-1.0

    return peaks


# ===========================================================================
# PER-ACCOUNT: PLAYLISTS
# ===========================================================================


@router.get("/api/accounts/{account_id}/playlists")
async def list_playlists(account_id: int):
    """List playlists for an account."""
    db = await get_db()
    try:
        await _ensure_account(db, account_id)
        cursor = await db.execute(
            """SELECT p.*,
                      (SELECT COUNT(*) FROM playlist_tracks pt WHERE pt.playlist_id = p.id) as track_count,
                      (SELECT COALESCE(SUM(t.duration), 0) FROM playlist_tracks pt
                       JOIN music_tracks t ON t.id = pt.track_id
                       WHERE pt.playlist_id = p.id) as total_duration
               FROM playlists p
               WHERE p.account_id = ?
               ORDER BY p.updated_at DESC""",
            (account_id,),
        )
        rows = await cursor.fetchall()
        return {"playlists": [row_to_dict(r) for r in rows]}
    finally:
        await db.close()


@router.get("/api/accounts/{account_id}/playlists/{playlist_id}")
async def get_playlist(account_id: int, playlist_id: int):
    """Get a playlist with its tracks."""
    db = await get_db()
    try:
        await _ensure_account(db, account_id)
        cursor = await db.execute(
            """SELECT p.*,
                      (SELECT COUNT(*) FROM playlist_tracks pt WHERE pt.playlist_id = p.id) as track_count,
                      (SELECT COALESCE(SUM(t.duration), 0) FROM playlist_tracks pt
                       JOIN music_tracks t ON t.id = pt.track_id
                       WHERE pt.playlist_id = p.id) as total_duration
               FROM playlists p
               WHERE p.id = ? AND p.account_id = ?""",
            (playlist_id, account_id),
        )
        playlist = await cursor.fetchone()
        if not playlist:
            raise HTTPException(404, "Playlist not found")

        cursor = await db.execute(
            """SELECT t.*, pt.position,
                      mad.favorite as is_favorite,
                      COALESCE(mad.play_count, 0) as play_count
               FROM playlist_tracks pt
               JOIN music_tracks t ON t.id = pt.track_id
               LEFT JOIN music_account_data mad ON mad.track_id = t.id AND mad.account_id = ?
               WHERE pt.playlist_id = ?
               ORDER BY pt.position""",
            (account_id, playlist_id),
        )
        tracks = await cursor.fetchall()

        result = row_to_dict(playlist)
        result["tracks"] = [row_to_dict(t) for t in tracks]
        return result
    finally:
        await db.close()


@router.post("/api/accounts/{account_id}/playlists", status_code=201)
async def create_playlist(account_id: int, data: PlaylistCreate):
    """Create a new playlist."""
    db = await get_db()
    try:
        await _ensure_account(db, account_id)
        now = datetime.utcnow().isoformat()
        cursor = await db.execute(
            "INSERT INTO playlists (account_id, name, description, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
            (account_id, data.name, data.description, now, now),
        )
        await db.commit()
        return {
            "id": cursor.lastrowid,
            "account_id": account_id,
            "name": data.name,
            "description": data.description,
            "created_at": now,
            "updated_at": now,
        }
    finally:
        await db.close()


@router.put("/api/accounts/{account_id}/playlists/{playlist_id}")
async def update_playlist(account_id: int, playlist_id: int, data: PlaylistUpdate):
    """Update a playlist."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM playlists WHERE id = ? AND account_id = ?",
            (playlist_id, account_id),
        )
        if not await cursor.fetchone():
            raise HTTPException(404, "Playlist not found")

        updates = []
        params = []
        if data.name is not None:
            updates.append("name = ?")
            params.append(data.name)
        if data.description is not None:
            updates.append("description = ?")
            params.append(data.description)

        if updates:
            updates.append("updated_at = ?")
            params.append(datetime.utcnow().isoformat())
            params.extend([playlist_id, account_id])
            await db.execute(
                f"UPDATE playlists SET {', '.join(updates)} WHERE id = ? AND account_id = ?",
                params,
            )
            await db.commit()

        cursor = await db.execute(
            "SELECT * FROM playlists WHERE id = ?", (playlist_id,)
        )
        return row_to_dict(await cursor.fetchone())
    finally:
        await db.close()


@router.delete("/api/accounts/{account_id}/playlists/{playlist_id}")
async def delete_playlist(account_id: int, playlist_id: int):
    """Delete a playlist."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id FROM playlists WHERE id = ? AND account_id = ?",
            (playlist_id, account_id),
        )
        if not await cursor.fetchone():
            raise HTTPException(404, "Playlist not found")
        await db.execute("DELETE FROM playlists WHERE id = ?", (playlist_id,))
        await db.commit()
        return {"deleted": playlist_id}
    finally:
        await db.close()


@router.post("/api/accounts/{account_id}/playlists/{playlist_id}/tracks")
async def add_tracks_to_playlist(
    account_id: int, playlist_id: int, data: PlaylistAddTracks
):
    """Add tracks to a playlist."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id FROM playlists WHERE id = ? AND account_id = ?",
            (playlist_id, account_id),
        )
        if not await cursor.fetchone():
            raise HTTPException(404, "Playlist not found")

        # Get current max position
        cursor = await db.execute(
            "SELECT COALESCE(MAX(position), 0) as max_pos FROM playlist_tracks WHERE playlist_id = ?",
            (playlist_id,),
        )
        pos = (await cursor.fetchone())["max_pos"]

        added = 0
        for tid in data.track_ids:
            # Verify track exists
            cursor = await db.execute(
                "SELECT id FROM music_tracks WHERE id = ?", (tid,)
            )
            if not await cursor.fetchone():
                continue
            pos += 1
            await db.execute(
                "INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES (?, ?, ?)",
                (playlist_id, tid, pos),
            )
            added += 1

        # Update playlist timestamp
        await db.execute(
            "UPDATE playlists SET updated_at = ? WHERE id = ?",
            (datetime.utcnow().isoformat(), playlist_id),
        )
        await db.commit()
        return {"added": added, "playlist_id": playlist_id}
    finally:
        await db.close()


@router.delete(
    "/api/accounts/{account_id}/playlists/{playlist_id}/tracks/{track_id}"
)
async def remove_track_from_playlist(
    account_id: int, playlist_id: int, track_id: int
):
    """Remove a track from a playlist."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id FROM playlists WHERE id = ? AND account_id = ?",
            (playlist_id, account_id),
        )
        if not await cursor.fetchone():
            raise HTTPException(404, "Playlist not found")

        await db.execute(
            "DELETE FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?",
            (playlist_id, track_id),
        )
        await db.execute(
            "UPDATE playlists SET updated_at = ? WHERE id = ?",
            (datetime.utcnow().isoformat(), playlist_id),
        )
        await db.commit()
        return {"removed": track_id, "playlist_id": playlist_id}
    finally:
        await db.close()


# ===========================================================================
# PER-ACCOUNT: RECENTLY PLAYED / FAVORITES / STATS
# ===========================================================================


@router.get("/api/accounts/{account_id}/music/recently-played")
async def music_recently_played(
    account_id: int, limit: int = Query(50, ge=1, le=200)
):
    """Recent listening history."""
    db = await get_db()
    try:
        await _ensure_account(db, account_id)
        cursor = await db.execute(
            """SELECT h.*, t.title, t.artist, t.album, t.duration, t.album_id
               FROM music_play_history h
               JOIN music_tracks t ON t.id = h.track_id
               WHERE h.account_id = ?
               ORDER BY h.played_at DESC
               LIMIT ?""",
            (account_id, limit),
        )
        rows = await cursor.fetchall()
        return {"items": [row_to_dict(r) for r in rows]}
    finally:
        await db.close()


@router.get("/api/accounts/{account_id}/music/favorites")
async def music_favorites(account_id: int):
    """Favorited tracks."""
    db = await get_db()
    try:
        await _ensure_account(db, account_id)
        cursor = await db.execute(
            """SELECT t.*, mad.play_count, mad.last_played, mad.total_listen_time
               FROM music_account_data mad
               JOIN music_tracks t ON t.id = mad.track_id
               WHERE mad.account_id = ? AND mad.favorite = 1
               ORDER BY mad.last_played DESC""",
            (account_id,),
        )
        rows = await cursor.fetchall()
        return {"items": [row_to_dict(r) for r in rows]}
    finally:
        await db.close()


@router.post("/api/accounts/{account_id}/music/favorites/{track_id}")
async def toggle_music_favorite(account_id: int, track_id: int):
    """Toggle favorite status for a music track."""
    db = await get_db()
    try:
        await _ensure_account(db, account_id)

        # Verify track exists
        cursor = await db.execute(
            "SELECT id FROM music_tracks WHERE id = ?", (track_id,)
        )
        if not await cursor.fetchone():
            raise HTTPException(404, "Track not found")

        # Upsert music_account_data
        await db.execute(
            "INSERT OR IGNORE INTO music_account_data (account_id, track_id, favorite, play_count, total_listen_time) "
            "VALUES (?, ?, 0, 0, 0)",
            (account_id, track_id),
        )

        cursor = await db.execute(
            "SELECT favorite FROM music_account_data WHERE account_id = ? AND track_id = ?",
            (account_id, track_id),
        )
        current = (await cursor.fetchone())["favorite"]
        new_val = 0 if current else 1

        await db.execute(
            "UPDATE music_account_data SET favorite = ? WHERE account_id = ? AND track_id = ?",
            (new_val, account_id, track_id),
        )
        await db.commit()
        return {
            "account_id": account_id,
            "track_id": track_id,
            "favorite": bool(new_val),
        }
    finally:
        await db.close()


@router.get("/api/accounts/{account_id}/music/stats")
async def music_account_stats(account_id: int):
    """Per-user listening stats: top artists, top genres, total listen time."""
    db = await get_db()
    try:
        await _ensure_account(db, account_id)

        stats = {"account_id": account_id}

        # Total listen time
        cursor = await db.execute(
            "SELECT COALESCE(SUM(total_listen_time), 0) as t FROM music_account_data WHERE account_id = ?",
            (account_id,),
        )
        total_sec = (await cursor.fetchone())["t"]
        stats["total_listen_time_seconds"] = total_sec
        stats["total_listen_time_hours"] = round(total_sec / 3600, 1)

        # Total plays
        cursor = await db.execute(
            "SELECT COALESCE(SUM(play_count), 0) as p FROM music_account_data WHERE account_id = ?",
            (account_id,),
        )
        stats["total_plays"] = (await cursor.fetchone())["p"]

        # Favorites count
        cursor = await db.execute(
            "SELECT COUNT(*) as c FROM music_account_data WHERE account_id = ? AND favorite = 1",
            (account_id,),
        )
        stats["favorites_count"] = (await cursor.fetchone())["c"]

        # Top artists by play count
        cursor = await db.execute(
            """SELECT t.artist, SUM(mad.play_count) as plays, SUM(mad.total_listen_time) as listen_time
               FROM music_account_data mad
               JOIN music_tracks t ON t.id = mad.track_id
               WHERE mad.account_id = ? AND mad.play_count > 0
               GROUP BY t.artist
               ORDER BY plays DESC
               LIMIT 10""",
            (account_id,),
        )
        stats["top_artists"] = [row_to_dict(r) for r in await cursor.fetchall()]

        # Top genres by play count
        cursor = await db.execute(
            """SELECT t.genre, SUM(mad.play_count) as plays, SUM(mad.total_listen_time) as listen_time
               FROM music_account_data mad
               JOIN music_tracks t ON t.id = mad.track_id
               WHERE mad.account_id = ? AND mad.play_count > 0 AND t.genre IS NOT NULL AND t.genre != ''
               GROUP BY t.genre
               ORDER BY plays DESC
               LIMIT 10""",
            (account_id,),
        )
        stats["top_genres"] = [row_to_dict(r) for r in await cursor.fetchall()]

        return stats
    finally:
        await db.close()


# ===========================================================================
# PER-ACCOUNT: QUEUE / PLAYBACK
# ===========================================================================


@router.get("/api/accounts/{account_id}/music/queue")
async def get_queue(account_id: int):
    """Get current playback queue (stored in music_account_queue)."""
    db = await get_db()
    try:
        await _ensure_account(db, account_id)

        # Queue is stored as a simple JSON array in server_settings with key "queue_{account_id}"
        cursor = await db.execute(
            "SELECT value FROM server_settings WHERE key = ?",
            (f"music_queue_{account_id}",),
        )
        row = await cursor.fetchone()
        if not row or not row["value"]:
            return {"queue": [], "tracks": []}

        import json

        track_ids = json.loads(row["value"])
        if not track_ids:
            return {"queue": [], "tracks": []}

        placeholders = ",".join("?" * len(track_ids))
        cursor = await db.execute(
            f"SELECT * FROM music_tracks WHERE id IN ({placeholders})", track_ids
        )
        tracks_map = {r["id"]: row_to_dict(r) for r in await cursor.fetchall()}
        ordered = [tracks_map[tid] for tid in track_ids if tid in tracks_map]

        return {"queue": track_ids, "tracks": ordered}
    finally:
        await db.close()


@router.put("/api/accounts/{account_id}/music/queue")
async def set_queue(account_id: int, data: QueueUpdate):
    """Set the playback queue (list of track IDs)."""
    db = await get_db()
    try:
        await _ensure_account(db, account_id)

        import json

        await db.execute(
            "INSERT OR REPLACE INTO server_settings (key, value) VALUES (?, ?)",
            (f"music_queue_{account_id}", json.dumps(data.track_ids)),
        )
        await db.commit()
        return {"queue": data.track_ids}
    finally:
        await db.close()


@router.post("/api/accounts/{account_id}/music/history")
async def log_play(account_id: int, data: PlayHistoryLog):
    """Log a play event: records history and updates account data aggregates."""
    db = await get_db()
    try:
        await _ensure_account(db, account_id)

        # Verify track exists
        cursor = await db.execute(
            "SELECT id FROM music_tracks WHERE id = ?", (data.track_id,)
        )
        if not await cursor.fetchone():
            raise HTTPException(404, "Track not found")

        now = datetime.utcnow().isoformat()

        # Insert history record
        await db.execute(
            "INSERT INTO music_play_history (account_id, track_id, played_at, duration_listened) VALUES (?, ?, ?, ?)",
            (account_id, data.track_id, now, data.duration_listened),
        )

        # Upsert music_account_data
        await db.execute(
            "INSERT OR IGNORE INTO music_account_data (account_id, track_id, favorite, play_count, total_listen_time) "
            "VALUES (?, ?, 0, 0, 0)",
            (account_id, data.track_id),
        )
        await db.execute(
            """UPDATE music_account_data SET
               play_count = play_count + 1,
               last_played = ?,
               total_listen_time = total_listen_time + ?
               WHERE account_id = ? AND track_id = ?""",
            (now, data.duration_listened, account_id, data.track_id),
        )
        await db.commit()

        return {
            "account_id": account_id,
            "track_id": data.track_id,
            "played_at": now,
            "duration_listened": data.duration_listened,
        }
    finally:
        await db.close()
