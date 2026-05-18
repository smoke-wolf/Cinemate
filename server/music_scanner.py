"""Music scanner — walks directories, extracts metadata via mutagen, saves album art."""

import asyncio
import hashlib
import io
import logging
import os
import time
from pathlib import Path
from typing import Callable, Optional

from database import get_db, ALBUM_ART_DIR

logger = logging.getLogger("cinemate.music_scanner")

AUDIO_EXTENSIONS = {
    ".mp3", ".flac", ".aac", ".m4a", ".wav", ".ogg",
    ".wma", ".alac", ".aiff", ".opus",
}


class MusicScanState:
    """Tracks music scan progress."""

    def __init__(self):
        self.scanning = False
        self.total_files = 0
        self.processed_files = 0
        self.current_file = ""
        self.new_tracks = 0
        self.new_albums = 0
        self.skipped = 0
        self.errors = 0
        self.started_at: Optional[float] = None
        self.finished_at: Optional[float] = None

    def to_dict(self) -> dict:
        return {
            "scanning": self.scanning,
            "total_files": self.total_files,
            "processed_files": self.processed_files,
            "current_file": self.current_file,
            "new_tracks": self.new_tracks,
            "new_albums": self.new_albums,
            "skipped": self.skipped,
            "errors": self.errors,
            "progress_pct": round(
                (self.processed_files / self.total_files * 100)
                if self.total_files > 0
                else 0,
                1,
            ),
            "started_at": self.started_at,
            "finished_at": self.finished_at,
        }


music_scan_state = MusicScanState()


def find_audio_files(root: str) -> list[str]:
    """Recursively find all audio files under root (does not follow symlinks)."""
    audio_files = []
    for dirpath, _dirnames, filenames in os.walk(root, followlinks=False):
        for fname in filenames:
            if Path(fname).suffix.lower() in AUDIO_EXTENSIONS:
                audio_files.append(os.path.join(dirpath, fname))
    return sorted(audio_files)


def _extract_metadata(filepath: str) -> dict:
    """Extract audio metadata from a file using mutagen.

    Returns a dict with title, artist, album, album_artist, track_number,
    disc_number, year, genre, duration, bitrate, sample_rate, format.
    """
    import mutagen
    from mutagen.easyid3 import EasyID3
    from mutagen.mp3 import MP3
    from mutagen.flac import FLAC
    from mutagen.mp4 import MP4
    from mutagen.oggvorbis import OggVorbis
    from mutagen.oggopus import OggOpus
    from mutagen.aiff import AIFF

    result = {
        "title": Path(filepath).stem,
        "artist": "Unknown Artist",
        "album": None,
        "album_artist": None,
        "track_number": None,
        "disc_number": None,
        "year": None,
        "genre": None,
        "duration": 0.0,
        "bitrate": None,
        "sample_rate": None,
        "format": Path(filepath).suffix.lstrip(".").upper(),
    }

    try:
        audio = mutagen.File(filepath)
        if audio is None:
            return result

        # Duration
        if audio.info:
            result["duration"] = round(audio.info.length, 2) if audio.info.length else 0.0
            if hasattr(audio.info, "bitrate") and audio.info.bitrate:
                result["bitrate"] = audio.info.bitrate
            if hasattr(audio.info, "sample_rate") and audio.info.sample_rate:
                result["sample_rate"] = audio.info.sample_rate

        # MP4/M4A tags use different keys
        if isinstance(audio, MP4):
            tags = audio.tags or {}
            result["title"] = _first(tags.get("\xa9nam")) or result["title"]
            result["artist"] = _first(tags.get("\xa9ART")) or result["artist"]
            result["album"] = _first(tags.get("\xa9alb")) or result["album"]
            result["album_artist"] = _first(tags.get("aART"))
            result["genre"] = _first(tags.get("\xa9gen"))
            result["year"] = _parse_year(_first(tags.get("\xa9day")))
            trkn = tags.get("trkn")
            if trkn and isinstance(trkn[0], tuple):
                result["track_number"] = trkn[0][0]
            disk = tags.get("disk")
            if disk and isinstance(disk[0], tuple):
                result["disc_number"] = disk[0][0]
        else:
            # ID3 / Vorbis / FLAC — use EasyID3-style or direct tags
            tags = None
            if isinstance(audio, MP3):
                try:
                    tags = EasyID3(filepath)
                except Exception:
                    tags = audio.tags
            elif hasattr(audio, "tags") and audio.tags:
                tags = audio.tags

            if tags:
                result["title"] = _first(tags.get("title")) or result["title"]
                result["artist"] = _first(tags.get("artist")) or result["artist"]
                result["album"] = _first(tags.get("album")) or result["album"]
                result["album_artist"] = _first(tags.get("albumartist") or tags.get("album_artist"))
                result["genre"] = _first(tags.get("genre"))
                result["year"] = _parse_year(
                    _first(tags.get("date") or tags.get("year"))
                )
                result["track_number"] = _parse_track_num(
                    _first(tags.get("tracknumber"))
                )
                result["disc_number"] = _parse_track_num(
                    _first(tags.get("discnumber"))
                )

    except Exception as e:
        logger.debug(f"Metadata extraction error for {filepath}: {e}")

    if result["artist"] == "Unknown Artist":
        stem = Path(filepath).stem
        if " - " in stem:
            parts = stem.split(" - ", 1)
            result["artist"] = parts[0].strip()
            result["title"] = parts[1].strip()

    return result


def _first(val) -> Optional[str]:
    """Return first element if list, else the value itself, or None."""
    if val is None:
        return None
    if isinstance(val, (list, tuple)):
        return str(val[0]) if val else None
    return str(val)


def _parse_year(val: Optional[str]) -> Optional[int]:
    """Extract a 4-digit year from a string like '2023' or '2023-05-01'."""
    if not val:
        return None
    import re
    m = re.search(r"((?:19|20)\d{2})", val)
    if m:
        return int(m.group(1))
    return None


def _parse_track_num(val: Optional[str]) -> Optional[int]:
    """Parse track number from '3' or '3/12'."""
    if not val:
        return None
    try:
        return int(str(val).split("/")[0])
    except (ValueError, IndexError):
        return None


def extract_album_art(filepath: str, album_id: int) -> Optional[str]:
    """Extract embedded cover art from an audio file and save as JPEG.

    Returns the path to the saved art, or None.
    """
    import mutagen
    from mutagen.mp3 import MP3
    from mutagen.id3 import ID3
    from mutagen.flac import FLAC
    from mutagen.mp4 import MP4
    from mutagen.oggvorbis import OggVorbis

    ALBUM_ART_DIR.mkdir(parents=True, exist_ok=True)
    out_path = ALBUM_ART_DIR / f"{album_id}.jpg"
    if out_path.exists():
        return str(out_path)

    try:
        audio = mutagen.File(filepath)
        if audio is None:
            return None

        image_data = None

        # MP3 — ID3 APIC frames
        if isinstance(audio, MP3):
            try:
                tags = ID3(filepath)
                for key in tags:
                    if key.startswith("APIC"):
                        image_data = tags[key].data
                        break
            except Exception:
                pass

        # FLAC — audio.pictures
        elif isinstance(audio, FLAC):
            if audio.pictures:
                image_data = audio.pictures[0].data

        # MP4/M4A — covr
        elif isinstance(audio, MP4):
            covers = (audio.tags or {}).get("covr")
            if covers:
                image_data = bytes(covers[0])

        # Ogg Vorbis — metadata_block_picture
        elif isinstance(audio, OggVorbis):
            import base64
            from mutagen.flac import Picture
            pics = audio.get("metadata_block_picture")
            if pics:
                try:
                    pic = Picture(base64.b64decode(pics[0]))
                    image_data = pic.data
                except Exception:
                    pass

        if image_data and len(image_data) > 100:
            # Convert to JPEG if needed, or save directly
            try:
                from PIL import Image
                img = Image.open(io.BytesIO(image_data))
                img = img.convert("RGB")
                img.save(str(out_path), "JPEG", quality=85)
            except ImportError:
                # No PIL — just save raw bytes (likely already JPEG)
                with open(out_path, "wb") as f:
                    f.write(image_data)
            return str(out_path)

    except Exception as e:
        logger.debug(f"Album art extraction error for {filepath}: {e}")

    return None


def _album_key(meta: dict) -> str:
    """Generate a stable key for deduplicating albums."""
    artist = (meta.get("album_artist") or meta.get("artist") or "Unknown Artist").strip().lower()
    album = (meta.get("album") or f"{meta.get('artist', 'Unknown Artist')} - Singles").strip().lower()
    return f"{artist}||{album}"


async def scan_music_directory(path: str, ws_broadcast: Optional[Callable] = None):
    """Scan a directory tree for audio files, extract metadata, populate DB."""
    global music_scan_state

    if music_scan_state.scanning:
        logger.warning("Music scan already in progress")
        return

    music_scan_state = MusicScanState()
    music_scan_state.scanning = True
    music_scan_state.started_at = time.time()

    try:
        if not os.path.isdir(path):
            raise ValueError(f"Directory not found: {path}")

        logger.info(f"Scanning music directory: {path}")
        audio_files = await asyncio.to_thread(find_audio_files, path)
        music_scan_state.total_files = len(audio_files)
        logger.info(f"Found {len(audio_files)} audio files")

        if ws_broadcast:
            await ws_broadcast({
                "type": "music_scan_started",
                "total_files": len(audio_files),
                "path": path,
            })

        # Track albums we've seen in this scan to avoid re-querying
        album_cache: dict[str, int] = {}  # album_key -> album_id

        db = await get_db()
        try:
            for filepath in audio_files:
                music_scan_state.current_file = os.path.basename(filepath)
                music_scan_state.processed_files += 1

                try:
                    # Skip duplicates by file_path
                    cursor = await db.execute(
                        "SELECT id FROM music_tracks WHERE file_path = ?", (filepath,)
                    )
                    if await cursor.fetchone():
                        music_scan_state.skipped += 1
                        continue

                    # Extract metadata in thread
                    meta = await asyncio.to_thread(_extract_metadata, filepath)
                    file_size = os.path.getsize(filepath)

                    # Resolve or create album
                    akey = _album_key(meta)
                    album_id = album_cache.get(akey)

                    if album_id is None:
                        # Check DB
                        album_artist = meta.get("album_artist") or meta.get("artist") or "Unknown Artist"
                        album_name = meta.get("album") or f"{album_artist} - Singles"
                        cursor = await db.execute(
                            "SELECT id FROM music_albums WHERE LOWER(name) = LOWER(?) AND LOWER(artist) = LOWER(?)",
                            (album_name, album_artist),
                        )
                        row = await cursor.fetchone()
                        if row:
                            album_id = row["id"]
                        else:
                            cursor = await db.execute(
                                """INSERT INTO music_albums
                                   (name, artist, album_artist, year, genre, track_count, total_duration, art_path)
                                   VALUES (?, ?, ?, ?, ?, 0, 0, NULL)""",
                                (
                                    album_name,
                                    album_artist,
                                    meta.get("album_artist"),
                                    meta.get("year"),
                                    meta.get("genre"),
                                ),
                            )
                            album_id = cursor.lastrowid
                            music_scan_state.new_albums += 1

                        album_cache[akey] = album_id

                    # Extract album art if we don't have it yet
                    cursor = await db.execute(
                        "SELECT art_path FROM music_albums WHERE id = ?", (album_id,)
                    )
                    album_row = await cursor.fetchone()
                    if album_row and not album_row["art_path"]:
                        art_path = await asyncio.to_thread(
                            extract_album_art, filepath, album_id
                        )
                        if art_path:
                            await db.execute(
                                "UPDATE music_albums SET art_path = ? WHERE id = ?",
                                (art_path, album_id),
                            )

                    # Insert track
                    cursor = await db.execute(
                        """INSERT INTO music_tracks
                           (title, artist, album, album_artist, track_number, disc_number,
                            year, genre, duration, bitrate, sample_rate, format,
                            file_path, file_size, album_art_path, album_id)
                           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                        (
                            meta["title"],
                            meta["artist"],
                            meta["album"],
                            meta.get("album_artist"),
                            meta.get("track_number"),
                            meta.get("disc_number"),
                            meta.get("year"),
                            meta.get("genre"),
                            meta["duration"],
                            meta.get("bitrate"),
                            meta.get("sample_rate"),
                            meta["format"],
                            filepath,
                            file_size,
                            (album_row["art_path"] if album_row and album_row["art_path"] else None),
                            album_id,
                        ),
                    )
                    await db.commit()
                    music_scan_state.new_tracks += 1

                    # Update album aggregates
                    await db.execute(
                        """UPDATE music_albums SET
                           track_count = (SELECT COUNT(*) FROM music_tracks WHERE album_id = ?),
                           total_duration = (SELECT COALESCE(SUM(duration), 0) FROM music_tracks WHERE album_id = ?)
                           WHERE id = ?""",
                        (album_id, album_id, album_id),
                    )
                    await db.commit()

                    if ws_broadcast:
                        await ws_broadcast({
                            "type": "music_track_added",
                            "title": meta["title"],
                            "artist": meta["artist"],
                            "album": meta["album"],
                        })

                except Exception as e:
                    music_scan_state.errors += 1
                    logger.error(f"Error processing {filepath}: {e}")

                # Broadcast progress periodically
                if ws_broadcast and music_scan_state.processed_files % 10 == 0:
                    await ws_broadcast({
                        "type": "music_scan_progress",
                        **music_scan_state.to_dict(),
                    })

        finally:
            await db.close()

    except Exception as e:
        logger.error(f"Music scan failed: {e}")
        music_scan_state.errors += 1
    finally:
        music_scan_state.scanning = False
        music_scan_state.finished_at = time.time()
        music_scan_state.current_file = ""

        if ws_broadcast:
            await ws_broadcast({
                "type": "music_scan_complete",
                **music_scan_state.to_dict(),
            })

        logger.info(
            f"Music scan complete: {music_scan_state.new_tracks} new tracks, "
            f"{music_scan_state.new_albums} new albums, "
            f"{music_scan_state.skipped} skipped, "
            f"{music_scan_state.errors} errors, "
            f"{music_scan_state.processed_files}/{music_scan_state.total_files} processed"
        )
