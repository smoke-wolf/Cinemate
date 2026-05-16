"""
Cinemate Transcoding Module
============================
On-the-fly and cached transcoding for iOS-incompatible video formats.

iOS natively supports: H.264/H.265 video + AAC audio in MP4/MOV/M4V containers.
Everything else (MKV containers, AC3/DTS/FLAC audio, VP9/AV1 video, etc.) needs
transcoding before the iOS AVPlayer can handle it.

Transcoded files are cached in ~/.cinemate/transcode_cache/ to avoid re-work.
"""

import asyncio
import json
import logging
import os
import subprocess
import hashlib
import time
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import FileResponse, StreamingResponse

from database import get_db, DB_DIR

logger = logging.getLogger("cinemate.transcode")

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
TRANSCODE_CACHE_DIR = DB_DIR / "transcode_cache"
TRANSCODE_CACHE_DIR.mkdir(parents=True, exist_ok=True)

# iOS-compatible codecs and containers
IOS_VIDEO_CODECS = {"h264", "hevc", "h265", "mpeg4"}
IOS_AUDIO_CODECS = {"aac", "alac", "mp3", "pcm_s16le", "pcm_s24le", "pcm_f32le"}
IOS_CONTAINERS = {"mp4", "mov", "m4v"}

# Active transcode processes: media_id -> asyncio.subprocess.Process
_active_transcodes: dict[int, asyncio.subprocess.Process] = {}

router = APIRouter(prefix="/api/stream", tags=["transcode"])


# ---------------------------------------------------------------------------
# FFprobe helpers
# ---------------------------------------------------------------------------
def probe_file(file_path: str) -> Optional[dict]:
    """Run ffprobe and return parsed JSON with streams and format info."""
    try:
        result = subprocess.run(
            [
                "ffprobe",
                "-v", "quiet",
                "-print_format", "json",
                "-show_format",
                "-show_streams",
                file_path,
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
    except Exception as e:
        logger.error(f"ffprobe failed for {file_path}: {e}")
    return None


def extract_media_info(probe_data: dict) -> dict:
    """Extract codec/container info from ffprobe output."""
    fmt = probe_data.get("format", {})
    streams = probe_data.get("streams", [])

    container = (fmt.get("format_name") or "").split(",")[0].lower()
    # Normalize container names
    container_map = {
        "matroska": "mkv",
        "webm": "webm",
        "mov": "mov",
        "mp4": "mp4",
        "avi": "avi",
        "flv": "flv",
        "wmv": "wmv",
    }
    for key, val in container_map.items():
        if key in container:
            container = val
            break

    video_codec = None
    audio_codec = None
    video_width = None
    video_height = None
    duration = float(fmt.get("duration", 0))

    for stream in streams:
        codec_type = stream.get("codec_type", "")
        codec_name = stream.get("codec_name", "").lower()

        if codec_type == "video" and video_codec is None:
            video_codec = codec_name
            video_width = stream.get("width")
            video_height = stream.get("height")
        elif codec_type == "audio" and audio_codec is None:
            audio_codec = codec_name

    return {
        "container": container,
        "video_codec": video_codec,
        "audio_codec": audio_codec,
        "width": video_width,
        "height": video_height,
        "duration": duration,
        "file_size": int(fmt.get("size", 0)),
    }


def check_moov_at_start(file_path: str) -> bool:
    """Check if the moov atom is before mdat (faststart-ready)."""
    import struct
    try:
        with open(file_path, "rb") as f:
            pos = 0
            for _ in range(30):
                header = f.read(8)
                if len(header) < 8:
                    return True
                size = struct.unpack(">I", header[:4])[0]
                atom = header[4:8]
                if size == 1:
                    ext = f.read(8)
                    size = struct.unpack(">Q", ext)[0]
                if atom == b"moov":
                    return True
                if atom == b"mdat":
                    return False
                if size < 8:
                    return True
                f.seek(pos + size)
                pos = f.tell()
    except Exception:
        pass
    return True


def check_ios_compatible(info: dict) -> tuple[bool, list[str]]:
    """
    Check if the file is natively playable on iOS.
    Returns (is_compatible, list_of_reasons_why_not).
    """
    reasons = []

    if info["container"] not in IOS_CONTAINERS:
        reasons.append(f"container '{info['container']}' not supported (need mp4/mov/m4v)")

    if info["video_codec"] and info["video_codec"] not in IOS_VIDEO_CODECS:
        reasons.append(f"video codec '{info['video_codec']}' not supported (need h264/hevc)")

    if info["audio_codec"] and info["audio_codec"] not in IOS_AUDIO_CODECS:
        reasons.append(f"audio codec '{info['audio_codec']}' not supported (need aac/alac/mp3)")

    return (len(reasons) == 0, reasons)


# ---------------------------------------------------------------------------
# Cache management
# ---------------------------------------------------------------------------
def _cache_key(file_path: str, mtime: float) -> str:
    """Stable cache key based on path + modification time."""
    raw = f"{file_path}:{mtime}"
    return hashlib.sha256(raw.encode()).hexdigest()[:16]


def get_cached_path(file_path: str) -> Optional[str]:
    """Return path to cached transcode if it exists, else None."""
    if not os.path.exists(file_path):
        return None
    mtime = os.path.getmtime(file_path)
    key = _cache_key(file_path, mtime)
    cached = TRANSCODE_CACHE_DIR / f"{key}.mp4"
    if cached.exists() and cached.stat().st_size > 0:
        return str(cached)
    return None


def cache_target_path(file_path: str) -> str:
    """Return the path where a transcode should be cached."""
    mtime = os.path.getmtime(file_path)
    key = _cache_key(file_path, mtime)
    return str(TRANSCODE_CACHE_DIR / f"{key}.mp4")


# ---------------------------------------------------------------------------
# Helper: fetch media row from DB
# ---------------------------------------------------------------------------
async def _get_media_row(media_id: int) -> dict:
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id, file_path, format, title FROM media WHERE id = ?", (media_id,)
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Media not found")
        return dict(row)
    finally:
        await db.close()


# ---------------------------------------------------------------------------
# Endpoint: media info (codec probe)
# ---------------------------------------------------------------------------
@router.get("/{media_id}/info")
async def stream_info(media_id: int):
    """
    Probe a media file and report whether iOS transcoding is needed.

    Returns:
        needs_transcode: bool
        container: str (e.g. "mkv", "mp4")
        video_codec: str (e.g. "h264", "vp9")
        audio_codec: str (e.g. "aac", "ac3")
        width/height: int
        duration: float (seconds)
        reasons: list[str] — why transcoding is needed (empty if compatible)
        cached: bool — whether a transcoded version is already cached
    """
    row = await _get_media_row(media_id)
    file_path = row["file_path"]

    if not os.path.exists(file_path):
        raise HTTPException(404, f"File not found on disk")

    probe_data = await asyncio.to_thread(probe_file, file_path)
    if not probe_data:
        raise HTTPException(500, "Failed to probe media file")

    info = extract_media_info(probe_data)
    compatible, reasons = check_ios_compatible(info)

    return {
        "media_id": media_id,
        "needs_transcode": not compatible,
        "container": info["container"],
        "video_codec": info["video_codec"],
        "audio_codec": info["audio_codec"],
        "width": info["width"],
        "height": info["height"],
        "duration": info["duration"],
        "file_size": info["file_size"],
        "reasons": reasons,
        "cached": get_cached_path(file_path) is not None,
    }


# ---------------------------------------------------------------------------
# Endpoint: transcode stream
# ---------------------------------------------------------------------------
@router.api_route("/{media_id}/transcode", methods=["GET", "HEAD"])
async def stream_transcode(media_id: int, request: Request):
    """
    Stream a transcoded (iOS-compatible) version of the media file.

    Behavior:
    1. If the file is already iOS-compatible, redirect to the raw stream.
    2. If a cached transcode exists, serve it directly with Range support.
    3. Otherwise, start FFmpeg transcoding. If the request can wait for a
       full transcode (small files or patient clients), cache the result.
       For large files, stream the FFmpeg output directly as fragmented MP4.
    """
    row = await _get_media_row(media_id)
    file_path = row["file_path"]

    if not os.path.exists(file_path):
        raise HTTPException(404, "File not found on disk")

    # Probe the file
    probe_data = await asyncio.to_thread(probe_file, file_path)
    if not probe_data:
        raise HTTPException(500, "Failed to probe media file")

    info = extract_media_info(probe_data)
    compatible, _ = check_ios_compatible(info)

    # --- Case 1: Already compatible ---
    if compatible:
        # Check if cached faststart version exists
        cached = get_cached_path(file_path)
        if cached:
            return await _serve_file(cached, request)

        # Check if moov atom is at start (faststart-ready)
        moov_ok = await asyncio.to_thread(check_moov_at_start, file_path)
        if moov_ok:
            return await _serve_file(file_path, request)

        # moov at end — remux with faststart (no re-encode, fast)
        logger.info(f"Remuxing media {media_id} with faststart (moov at end)")
        target = cache_target_path(file_path)
        cmd = [
            "ffmpeg", "-y", "-i", file_path,
            "-c", "copy", "-movflags", "+faststart",
            target,
        ]
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.PIPE,
        )
        await proc.wait()
        if proc.returncode == 0 and os.path.exists(target):
            logger.info(f"Faststart cache ready for media {media_id}")
            return await _serve_file(target, request)

        # Faststart remux failed — serve original (slow start but works)
        logger.warning(f"Faststart remux failed for media {media_id}, serving original")
        return await _serve_file(file_path, request)

    # --- Case 2: Cached transcode exists ---
    cached = get_cached_path(file_path)
    if cached:
        logger.info(f"Serving cached transcode for media {media_id}")
        return await _serve_file(cached, request)

    # --- Case 3: Transcode needed ---
    logger.info(
        f"Transcoding media {media_id}: {info['video_codec']}/{info['audio_codec']} "
        f"in {info['container']} -> h264/aac in mp4"
    )

    # Build FFmpeg command
    target = cache_target_path(file_path)
    temp_target = target + ".tmp"

    # Determine what needs transcoding
    video_needs_transcode = info["video_codec"] not in IOS_VIDEO_CODECS
    audio_needs_transcode = info["audio_codec"] not in IOS_AUDIO_CODECS

    ffmpeg_cmd = ["ffmpeg", "-y", "-i", file_path]

    # Video: copy if compatible, transcode if not
    if video_needs_transcode:
        ffmpeg_cmd += [
            "-c:v", "libx264",
            "-preset", "fast",
            "-crf", "22",
            "-profile:v", "high",
            "-level", "4.1",
            "-pix_fmt", "yuv420p",
        ]
    else:
        ffmpeg_cmd += ["-c:v", "copy"]

    # Audio: copy if compatible, transcode if not
    if audio_needs_transcode:
        ffmpeg_cmd += [
            "-c:a", "aac",
            "-b:a", "192k",
            "-ac", "2",
        ]
    else:
        ffmpeg_cmd += ["-c:a", "copy"]

    # Subtitle: strip (iOS handles them differently)
    ffmpeg_cmd += ["-sn"]

    # For streaming: use fragmented MP4 that can be played before completion
    # Write to a pipe for immediate streaming, AND cache to disk
    ffmpeg_cmd += [
        "-movflags", "frag_keyframe+empty_moov+faststart+default_base_moof",
        "-f", "mp4",
    ]

    # Strategy: pipe output to client while simultaneously writing to cache
    ffmpeg_cmd.append(temp_target)

    # Start the background transcode, then stream from the growing file
    process = await asyncio.create_subprocess_exec(
        *ffmpeg_cmd,
        stdout=asyncio.subprocess.DEVNULL,
        stderr=asyncio.subprocess.PIPE,
    )
    _active_transcodes[media_id] = process

    async def stream_growing_file():
        """Stream from the temp file as FFmpeg writes to it."""
        bytes_sent = 0
        stall_count = 0
        max_stalls = 50  # 50 * 0.2s = 10 seconds of no new data before giving up

        # Wait for file to appear
        for _ in range(50):
            if os.path.exists(temp_target) and os.path.getsize(temp_target) > 0:
                break
            await asyncio.sleep(0.1)
        else:
            logger.error(f"Transcode output never appeared for media {media_id}")
            return

        try:
            with open(temp_target, "rb") as f:
                while True:
                    chunk = f.read(256 * 1024)  # 256KB chunks
                    if chunk:
                        bytes_sent += len(chunk)
                        stall_count = 0
                        yield chunk
                    else:
                        # No new data — is FFmpeg still running?
                        if process.returncode is not None:
                            # FFmpeg finished, read any remaining data
                            remaining = f.read()
                            if remaining:
                                yield remaining
                            break
                        stall_count += 1
                        if stall_count >= max_stalls:
                            logger.warning(
                                f"Transcode stalled for media {media_id}, "
                                f"sent {bytes_sent} bytes"
                            )
                            break
                        await asyncio.sleep(0.2)
        finally:
            # Wait for FFmpeg to finish
            try:
                await asyncio.wait_for(process.wait(), timeout=5.0)
            except asyncio.TimeoutError:
                process.kill()
                await process.wait()

            # Finalize cache: rename temp to final if successful
            if process.returncode == 0 and os.path.exists(temp_target):
                try:
                    os.rename(temp_target, target)
                    logger.info(
                        f"Transcode cached for media {media_id}: "
                        f"{os.path.getsize(target)} bytes"
                    )
                except OSError as e:
                    logger.error(f"Failed to finalize cache for media {media_id}: {e}")
            else:
                # Clean up failed transcode
                stderr_output = ""
                if process.stderr:
                    try:
                        stderr_bytes = await asyncio.wait_for(
                            process.stderr.read(), timeout=2.0
                        )
                        stderr_output = stderr_bytes.decode(errors="replace")[-500:]
                    except Exception:
                        pass
                logger.error(
                    f"Transcode failed for media {media_id} "
                    f"(exit {process.returncode}): {stderr_output}"
                )
                if os.path.exists(temp_target):
                    try:
                        os.remove(temp_target)
                    except OSError:
                        pass

            _active_transcodes.pop(media_id, None)

    return StreamingResponse(
        stream_growing_file(),
        media_type="video/mp4",
        headers={
            "Content-Type": "video/mp4",
            "Accept-Ranges": "none",  # Can't seek during live transcode
            "X-Cinemate-Transcode": "live",
            "Cache-Control": "no-cache",
        },
    )


# ---------------------------------------------------------------------------
# Serve a file with full Range request support
# ---------------------------------------------------------------------------
async def _serve_file(file_path: str, request: Request):
    """Serve a file with HTTP Range support (for seeking in cached transcodes)."""
    from starlette.responses import Response as StarletteResponse
    file_size = os.path.getsize(file_path)

    if request.method == "HEAD":
        return StarletteResponse(
            status_code=200,
            headers={
                "Accept-Ranges": "bytes",
                "Content-Length": str(file_size),
                "Content-Type": "video/mp4",
            },
        )

    range_header = request.headers.get("range")

    if range_header:
        range_spec = range_header.replace("bytes=", "")
        parts = range_spec.split("-")
        start = int(parts[0]) if parts[0] else 0
        end = int(parts[1]) if parts[1] else file_size - 1
        end = min(end, file_size - 1)
        chunk_size = end - start + 1

        async def ranged():
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
            ranged(),
            status_code=206,
            headers={
                "Content-Range": f"bytes {start}-{end}/{file_size}",
                "Accept-Ranges": "bytes",
                "Content-Length": str(chunk_size),
                "Content-Type": "video/mp4",
            },
        )
    else:
        return FileResponse(
            file_path,
            media_type="video/mp4",
            headers={
                "Accept-Ranges": "bytes",
                "Content-Length": str(file_size),
            },
        )


# ---------------------------------------------------------------------------
# Endpoint: transcode status (is a transcode in progress?)
# ---------------------------------------------------------------------------
@router.get("/{media_id}/transcode/status")
async def transcode_status(media_id: int):
    """Check if a transcode is currently in progress for this media item."""
    row = await _get_media_row(media_id)
    file_path = row["file_path"]

    in_progress = media_id in _active_transcodes
    cached = get_cached_path(file_path) is not None if os.path.exists(file_path) else False

    # Check temp file progress
    progress_pct = None
    if in_progress and os.path.exists(file_path):
        target = cache_target_path(file_path)
        temp = target + ".tmp"
        if os.path.exists(temp):
            original_size = os.path.getsize(file_path)
            current_size = os.path.getsize(temp)
            if original_size > 0:
                # Rough estimate — transcoded files are usually similar size
                progress_pct = min(round((current_size / original_size) * 100, 1), 99.0)

    return {
        "media_id": media_id,
        "in_progress": in_progress,
        "cached": cached,
        "progress_pct": progress_pct,
    }


# ---------------------------------------------------------------------------
# Endpoint: clear transcode cache
# ---------------------------------------------------------------------------
@router.delete("/cache")
async def clear_transcode_cache():
    """Delete all cached transcodes to free disk space."""
    count = 0
    total_bytes = 0
    for f in TRANSCODE_CACHE_DIR.iterdir():
        if f.suffix == ".mp4":
            total_bytes += f.stat().st_size
            f.unlink()
            count += 1
    return {
        "deleted": count,
        "freed_bytes": total_bytes,
        "freed_mb": round(total_bytes / (1024 * 1024), 1),
    }


@router.delete("/{media_id}/cache")
async def clear_media_cache(media_id: int):
    """Delete the cached transcode for a specific media item."""
    row = await _get_media_row(media_id)
    file_path = row["file_path"]

    if not os.path.exists(file_path):
        raise HTTPException(404, "Source file not found")

    cached = get_cached_path(file_path)
    if cached and os.path.exists(cached):
        size = os.path.getsize(cached)
        os.remove(cached)
        return {"deleted": True, "freed_bytes": size}

    return {"deleted": False, "message": "No cached transcode found"}


# ---------------------------------------------------------------------------
# Background: pre-cache faststart for all media
# ---------------------------------------------------------------------------
_precache_running = False


async def precache_faststart_all():
    """Scan all media and create faststart-cached copies for files with moov at end."""
    global _precache_running
    if _precache_running:
        return
    _precache_running = True

    try:
        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT id, file_path, format FROM media"
            )
            rows = await cursor.fetchall()
        finally:
            await db.close()

        processed = 0
        skipped = 0
        for row in rows:
            media_id = row["id"]
            file_path = row["file_path"]

            if not os.path.exists(file_path):
                skipped += 1
                continue

            if get_cached_path(file_path):
                skipped += 1
                continue

            probe_data = await asyncio.to_thread(probe_file, file_path)
            if not probe_data:
                skipped += 1
                continue

            info = extract_media_info(probe_data)
            compatible, _ = check_ios_compatible(info)

            if compatible:
                moov_ok = await asyncio.to_thread(check_moov_at_start, file_path)
                if moov_ok:
                    skipped += 1
                    continue

                target = cache_target_path(file_path)
                logger.info(f"[precache] Faststart remux media {media_id}: {row['format']}")
                cmd = [
                    "ffmpeg", "-y", "-i", file_path,
                    "-c", "copy", "-movflags", "+faststart",
                    target,
                ]
                proc = await asyncio.create_subprocess_exec(
                    *cmd,
                    stdout=asyncio.subprocess.DEVNULL,
                    stderr=asyncio.subprocess.DEVNULL,
                )
                await proc.wait()
                if proc.returncode == 0:
                    processed += 1
                else:
                    logger.warning(f"[precache] Failed for media {media_id}")
                    if os.path.exists(target):
                        os.remove(target)
            else:
                skipped += 1

        logger.info(f"[precache] Done: {processed} remuxed, {skipped} skipped")
    except Exception as e:
        logger.error(f"[precache] Error: {e}")
    finally:
        _precache_running = False


@router.post("/precache")
async def trigger_precache():
    """Trigger background pre-caching of faststart versions for all media."""
    if _precache_running:
        return {"status": "already_running"}
    asyncio.create_task(precache_faststart_all())
    return {"status": "started"}
