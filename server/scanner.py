"""Media scanner — walks directories, parses filenames, generates thumbnails."""

import asyncio
import logging
import os
import re
import subprocess
import time
from pathlib import Path
from typing import Optional

from database import get_db, THUMBNAIL_DIR

logger = logging.getLogger("cinemate.scanner")

VIDEO_EXTENSIONS = {".mp4", ".mkv", ".avi", ".mov", ".m4v", ".wmv", ".flv", ".webm"}

# Quality tags to strip from filenames.
# Uses word boundaries (\b) to avoid matching substrings (e.g. "TS" inside "Cats").
QUALITY_TAGS = re.compile(
    r"(?:[\.\s\-_])?"
    r"\b(2160p|1080p|720p|480p|4K|UHD|BluRay|Blu[\-\s]?Ray|BRRip|BDRip|DVDRip|"
    r"HDRip|WEB[\-\s]?DL|WEBRip|WEB|HDTV|PDTV|CAM|TS|TC|SCR|R5|DVDSCR|"
    r"x264|x265|h264|h265|HEVC|AVC|AAC|AC3|DTS|DD5\.1|FLAC|MP3|"
    r"REMUX|PROPER|REPACK|EXTENDED|UNRATED|DC|IMAX|"
    r"10bit|HDR|HDR10|DV|Atmos|TrueHD|"
    r"YIFY|YTS|RARBG|SPARKS|FGT|EVO|AMIABLE|GECKOS)\b"
    r"|(\[.*?\])"
    r"(?:[\.\s\-_])?",
    re.IGNORECASE,
)

# TV show patterns
TV_PATTERN_SE = re.compile(r"[Ss](\d{1,2})[Ee](\d{1,3})")
TV_PATTERN_LONG = re.compile(r"Season\s*(\d{1,2})\s*Episode\s*(\d{1,3})", re.IGNORECASE)
TV_PATTERN_X = re.compile(r"(\d{1,2})x(\d{1,3})")

# Year in parentheses or brackets
YEAR_PATTERN = re.compile(r"[\(\[\{]?((?:19|20)\d{2})[\)\]\}]?")


class ScanState:
    """Global scan state — tracks progress for the status endpoint."""

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


scan_state = ScanState()


def parse_filename(filepath: str) -> dict:
    """Extract title, year, quality, and TV show info from a filename."""
    name = Path(filepath).stem

    # Detect TV show pattern first
    media_type = "movie"
    show_name = None
    season_num = None
    episode_num = None

    se_match = TV_PATTERN_SE.search(name)
    if not se_match:
        se_match = TV_PATTERN_LONG.search(name)
    if not se_match:
        se_match = TV_PATTERN_X.search(name)

    if se_match:
        media_type = "tv"
        season_num = int(se_match.group(1))
        episode_num = int(se_match.group(2))
        # Show name is everything before the pattern
        show_name = name[: se_match.start()].strip(" .-_")
        # Episode title is everything between SE pattern and quality tags
        remaining = name[se_match.end():]
        remaining = QUALITY_TAGS.sub(" ", remaining).strip(" .-_")
        title_parts = [show_name]
        if remaining:
            title_parts.append(remaining)
        title = " - ".join(title_parts) if remaining else show_name
    else:
        title = name

    # Extract year
    year = None
    year_match = YEAR_PATTERN.search(title if media_type == "movie" else (show_name or title))
    if year_match:
        candidate = int(year_match.group(1))
        if 1920 <= candidate <= 2030:
            year = candidate
            if media_type == "movie":
                title = title[: year_match.start()] + title[year_match.end():]

    # Detect quality
    quality = None
    for tag in ["2160p", "4K", "UHD"]:
        if tag.lower() in name.lower():
            quality = "4K"
            break
    if not quality:
        if "1080p" in name.lower():
            quality = "1080p"
        elif "720p" in name.lower():
            quality = "720p"
        elif "480p" in name.lower():
            quality = "480p"

    # Clean title: strip quality tags, replace dots/underscores with spaces
    title = QUALITY_TAGS.sub(" ", title)
    title = re.sub(r"[._]", " ", title)
    title = re.sub(r"\s+", " ", title).strip(" -,()")

    if show_name:
        show_name = re.sub(r"[._]", " ", show_name)
        show_name = re.sub(r"\s+", " ", show_name).strip(" -,()")

    # Detect format from extension
    ext = Path(filepath).suffix.lower().lstrip(".")
    fmt = ext.upper()

    return {
        "title": title or Path(filepath).stem,
        "year": year,
        "quality": quality,
        "format": fmt,
        "media_type": media_type,
        "show_name": show_name,
        "season_number": season_num,
        "episode_number": episode_num,
    }


def get_file_duration(filepath: str) -> float:
    """Get video duration in seconds using ffprobe."""
    try:
        result = subprocess.run(
            [
                "ffprobe",
                "-v", "quiet",
                "-print_format", "json",
                "-show_format",
                filepath,
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            import json
            data = json.loads(result.stdout)
            return float(data.get("format", {}).get("duration", 0))
    except Exception as e:
        logger.debug(f"Could not get duration for {filepath}: {e}")
    return 0


def generate_thumbnail(filepath: str, media_id: int) -> Optional[str]:
    """Generate a thumbnail jpg using ffmpeg. Returns path or None."""
    out_path = str(THUMBNAIL_DIR / f"{media_id}.jpg")
    if os.path.exists(out_path):
        return out_path
    try:
        result = subprocess.run(
            [
                "ffmpeg",
                "-i", filepath,
                "-ss", "00:01:00",
                "-vframes", "1",
                "-vf", "scale=320:-1",
                "-y",
                out_path,
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode == 0 and os.path.exists(out_path):
            return out_path
        else:
            logger.debug(f"ffmpeg thumbnail failed for {filepath}: {result.stderr[:200]}")
    except FileNotFoundError:
        logger.warning("ffmpeg not found — skipping thumbnail generation")
    except Exception as e:
        logger.debug(f"Thumbnail error for {filepath}: {e}")
    return None


def find_video_files(root: str) -> list[str]:
    """Recursively find all video files under root."""
    videos = []
    for dirpath, _dirnames, filenames in os.walk(root):
        for fname in filenames:
            if Path(fname).suffix.lower() in VIDEO_EXTENSIONS:
                videos.append(os.path.join(dirpath, fname))
    return sorted(videos)


async def scan_directory(path: str, ws_broadcast=None):
    """Scan a directory tree, insert new media into DB, generate thumbnails."""
    global scan_state

    if scan_state.scanning:
        logger.warning("Scan already in progress")
        return

    scan_state = ScanState()
    scan_state.scanning = True
    scan_state.started_at = time.time()

    try:
        if not os.path.isdir(path):
            raise ValueError(f"Directory not found: {path}")

        logger.info(f"Scanning directory: {path}")
        videos = find_video_files(path)
        scan_state.total_files = len(videos)
        logger.info(f"Found {len(videos)} video files")

        if ws_broadcast:
            await ws_broadcast({
                "type": "scan_started",
                "total_files": len(videos),
                "path": path,
            })

        db = await get_db()
        try:
            for filepath in videos:
                scan_state.current_file = os.path.basename(filepath)
                scan_state.processed_files += 1

                try:
                    # Check if already in DB
                    cursor = await db.execute(
                        "SELECT id FROM media WHERE file_path = ?", (filepath,)
                    )
                    existing = await cursor.fetchone()
                    if existing:
                        continue

                    parsed = parse_filename(filepath)
                    file_size = os.path.getsize(filepath)

                    # Get duration (run in thread to avoid blocking)
                    duration = await asyncio.to_thread(get_file_duration, filepath)

                    cursor = await db.execute(
                        """INSERT INTO media
                           (title, year, file_path, file_size, format, quality,
                            media_type, show_name, season_number, episode_number, duration)
                           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                        (
                            parsed["title"],
                            parsed["year"],
                            filepath,
                            file_size,
                            parsed["format"],
                            parsed["quality"],
                            parsed["media_type"],
                            parsed["show_name"],
                            parsed["season_number"],
                            parsed["episode_number"],
                            duration,
                        ),
                    )
                    media_id = cursor.lastrowid
                    await db.commit()
                    scan_state.new_items += 1

                    # Generate thumbnail in background thread
                    thumb_path = await asyncio.to_thread(
                        generate_thumbnail, filepath, media_id
                    )
                    if thumb_path:
                        await db.execute(
                            "UPDATE media SET thumbnail_path = ? WHERE id = ?",
                            (thumb_path, media_id),
                        )
                        await db.commit()

                    if ws_broadcast:
                        await ws_broadcast({
                            "type": "media_added",
                            "media_id": media_id,
                            "title": parsed["title"],
                        })

                except Exception as e:
                    scan_state.errors += 1
                    logger.error(f"Error processing {filepath}: {e}")

                # Broadcast progress periodically
                if ws_broadcast and scan_state.processed_files % 5 == 0:
                    await ws_broadcast({
                        "type": "scan_progress",
                        **scan_state.to_dict(),
                    })

        finally:
            await db.close()

    except Exception as e:
        logger.error(f"Scan failed: {e}")
        scan_state.errors += 1
    finally:
        scan_state.scanning = False
        scan_state.finished_at = time.time()
        scan_state.current_file = ""

        if ws_broadcast:
            await ws_broadcast({
                "type": "scan_complete",
                **scan_state.to_dict(),
            })

        logger.info(
            f"Scan complete: {scan_state.new_items} new, "
            f"{scan_state.errors} errors, "
            f"{scan_state.processed_files}/{scan_state.total_files} processed"
        )
