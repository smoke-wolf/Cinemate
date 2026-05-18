"""Sync, download, upload, and device management routes for Cinemate."""

import asyncio
import hashlib
import json
import logging
import os
import struct
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, Request, UploadFile, File
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel

from database import get_db, UPLOAD_DIR

logger = logging.getLogger("cinemate.sync")

router = APIRouter(prefix="/api/sync", tags=["sync"])


# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------

class DeviceRegister(BaseModel):
    device_id: str
    name: str
    device_type: str  # "iphone", "ipad", "mac", "appletv", etc.
    platform_version: Optional[str] = None
    app_version: Optional[str] = None
    account_id: Optional[int] = None
    capabilities: list[str] = []
    storage_available_bytes: int = 0


class DeviceHeartbeat(BaseModel):
    is_online: bool = True
    storage_available_bytes: Optional[int] = None
    app_version: Optional[str] = None


class DiffRequest(BaseModel):
    device_id: str
    fingerprints: list[dict]  # [{"content_type": ..., "content_id": ..., "file_hash": ...}, ...]


class DownloadEnqueue(BaseModel):
    device_id: str
    items: list[dict]  # [{"content_type": "movie"|"music"|"book", "content_id": int}, ...]
    priority: int = 0


class DownloadUpdate(BaseModel):
    status: Optional[str] = None  # "paused", "queued", "cancelled"
    bytes_transferred: Optional[int] = None


class UploadPrepare(BaseModel):
    device_id: str
    file_name: str
    file_size: int
    file_hash: str
    content_type: str  # "movie", "music", "book"
    metadata: Optional[dict] = None


class UploadComplete(BaseModel):
    file_hash: str


class TransferCreate(BaseModel):
    source_device_id: str
    target_device_id: str
    content_type: str
    content_id: int
    priority: int = 0


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def row_to_dict(row) -> dict:
    if row is None:
        return {}
    return dict(row)


def compute_fingerprint(file_path: str) -> str:
    """SHA-256 of first 64KB + last 64KB + file_size as LE int64."""
    CHUNK = 65536  # 64KB
    file_size = os.path.getsize(file_path)
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        # First 64KB
        h.update(f.read(CHUNK))
        # Last 64KB (may overlap with first on small files)
        if file_size > CHUNK:
            f.seek(max(0, file_size - CHUNK))
        else:
            f.seek(0)
        h.update(f.read(CHUNK))
    # Append file size as little-endian int64
    h.update(struct.pack("<q", file_size))
    return h.hexdigest()


def _content_table(content_type: str) -> str:
    """Map content_type to its DB table name."""
    mapping = {"movie": "media", "tv": "media", "music": "music_tracks", "book": "books"}
    table = mapping.get(content_type)
    if not table:
        raise HTTPException(400, f"Unknown content_type: {content_type}")
    return table


async def _lookup_file_path(db, content_type: str, content_id: int) -> dict:
    """Look up file_path, file_size, title from the appropriate content table."""
    table = _content_table(content_type)
    cursor = await db.execute(
        f"SELECT id, title, file_path, file_size FROM {table} WHERE id = ?",
        (content_id,),
    )
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(404, f"{content_type} id={content_id} not found")
    return row_to_dict(row)


# ===========================================================================
# DEVICE REGISTRATION
# ===========================================================================

@router.post("/devices/register")
async def register_device(data: DeviceRegister):
    """Upsert a device record, return server info."""
    db = await get_db()
    try:
        now = datetime.utcnow().isoformat()
        caps_json = json.dumps(data.capabilities)
        await db.execute(
            """INSERT INTO devices (id, name, device_type, platform_version, app_version,
                   account_id, last_seen, is_online, capabilities, storage_available_bytes, registered_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)
               ON CONFLICT(id) DO UPDATE SET
                   name = excluded.name,
                   device_type = excluded.device_type,
                   platform_version = excluded.platform_version,
                   app_version = excluded.app_version,
                   account_id = excluded.account_id,
                   last_seen = excluded.last_seen,
                   is_online = 1,
                   capabilities = excluded.capabilities,
                   storage_available_bytes = excluded.storage_available_bytes""",
            (data.device_id, data.name, data.device_type, data.platform_version,
             data.app_version, data.account_id, now, caps_json,
             data.storage_available_bytes, now),
        )
        await db.commit()

        # Return server info alongside confirmation
        from database import load_config
        cfg = load_config()
        return {
            "device_id": data.device_id,
            "registered": True,
            "server_name": cfg.get("server_name", "Cinemate Server"),
            "server_version": "1.0.0",
        }
    finally:
        await db.close()


@router.post("/devices/{device_id}/heartbeat")
async def device_heartbeat(device_id: str, data: DeviceHeartbeat):
    """Update last_seen + is_online, return pending transfer count."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT id FROM devices WHERE id = ?", (device_id,))
        if not await cursor.fetchone():
            raise HTTPException(404, "Device not found")

        now = datetime.utcnow().isoformat()
        updates = ["last_seen = ?", "is_online = ?"]
        params: list = [now, 1 if data.is_online else 0]

        if data.storage_available_bytes is not None:
            updates.append("storage_available_bytes = ?")
            params.append(data.storage_available_bytes)
        if data.app_version is not None:
            updates.append("app_version = ?")
            params.append(data.app_version)

        params.append(device_id)
        await db.execute(
            f"UPDATE devices SET {', '.join(updates)} WHERE id = ?", params
        )
        await db.commit()

        # Pending transfers for this device
        cursor = await db.execute(
            "SELECT COUNT(*) as cnt FROM transfer_jobs WHERE target_device_id = ? AND status IN ('queued', 'downloading')",
            (device_id,),
        )
        pending = (await cursor.fetchone())["cnt"]

        return {
            "device_id": device_id,
            "last_seen": now,
            "is_online": data.is_online,
            "pending_transfers": pending,
        }
    finally:
        await db.close()


@router.get("/devices")
async def list_devices():
    """List all registered devices with online status."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM devices ORDER BY last_seen DESC"
        )
        rows = await cursor.fetchall()
        devices = []
        for r in rows:
            d = row_to_dict(r)
            # Parse capabilities JSON
            try:
                d["capabilities"] = json.loads(d.get("capabilities", "[]"))
            except (json.JSONDecodeError, TypeError):
                d["capabilities"] = []
            devices.append(d)
        return {"devices": devices, "total": len(devices)}
    finally:
        await db.close()


@router.get("/devices/{device_id}")
async def get_device(device_id: str):
    """Single device detail with library summary."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM devices WHERE id = ?", (device_id,))
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Device not found")
        d = row_to_dict(row)
        try:
            d["capabilities"] = json.loads(d.get("capabilities", "[]"))
        except (json.JSONDecodeError, TypeError):
            d["capabilities"] = []

        # Library summary
        cursor = await db.execute(
            "SELECT content_type, COUNT(*) as count, COALESCE(SUM(local_file_size), 0) as total_bytes "
            "FROM device_library WHERE device_id = ? GROUP BY content_type",
            (device_id,),
        )
        summary_rows = await cursor.fetchall()
        d["library_summary"] = [row_to_dict(s) for s in summary_rows]

        # Pending jobs
        cursor = await db.execute(
            "SELECT COUNT(*) as cnt FROM transfer_jobs WHERE target_device_id = ? AND status IN ('queued', 'downloading')",
            (device_id,),
        )
        d["pending_transfers"] = (await cursor.fetchone())["cnt"]

        return d
    finally:
        await db.close()


@router.get("/devices/{device_id}/library")
async def device_library(
    device_id: str,
    content_type: Optional[str] = None,
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
):
    """Browse what a device has downloaded."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT id FROM devices WHERE id = ?", (device_id,))
        if not await cursor.fetchone():
            raise HTTPException(404, "Device not found")

        conditions = ["dl.device_id = ?"]
        params: list = [device_id]
        if content_type:
            conditions.append("dl.content_type = ?")
            params.append(content_type)

        where = " WHERE " + " AND ".join(conditions)

        cursor = await db.execute(
            f"SELECT COUNT(*) as cnt FROM device_library dl{where}", params
        )
        total = (await cursor.fetchone())["cnt"]

        cursor = await db.execute(
            f"SELECT dl.* FROM device_library dl{where} ORDER BY dl.downloaded_at DESC LIMIT ? OFFSET ?",
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


@router.delete("/devices/{device_id}")
async def unregister_device(device_id: str):
    """Unregister a device (cascades to device_library)."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT id FROM devices WHERE id = ?", (device_id,))
        if not await cursor.fetchone():
            raise HTTPException(404, "Device not found")

        await db.execute("DELETE FROM devices WHERE id = ?", (device_id,))
        await db.commit()
        return {"deleted": device_id}
    finally:
        await db.close()


# ===========================================================================
# CONTENT FINGERPRINTING
# ===========================================================================

@router.post("/fingerprint-library")
async def fingerprint_library():
    """Background task to fingerprint all existing content."""
    async def _run_fingerprinting():
        db = await get_db()
        try:
            count = 0
            # Fingerprint movies/TV
            cursor = await db.execute(
                "SELECT id, title, file_path, file_size, duration, media_type FROM media"
            )
            rows = await cursor.fetchall()
            for r in rows:
                r = row_to_dict(r)
                fp = r["file_path"]
                if not fp or not os.path.exists(fp):
                    continue
                try:
                    fhash = await asyncio.to_thread(compute_fingerprint, fp)
                    ct = r.get("media_type", "movie")
                    title_norm = (r.get("title") or "").lower().strip()
                    await db.execute(
                        """INSERT INTO content_fingerprints
                               (content_type, content_id, file_hash, file_size, duration, title_normalized)
                           VALUES (?, ?, ?, ?, ?, ?)
                           ON CONFLICT(content_type, content_id) DO UPDATE SET
                               file_hash = excluded.file_hash,
                               file_size = excluded.file_size,
                               duration = excluded.duration,
                               title_normalized = excluded.title_normalized""",
                        (ct, r["id"], fhash, r.get("file_size", 0),
                         r.get("duration"), title_norm),
                    )
                    count += 1
                except Exception as e:
                    logger.warning(f"Fingerprint failed for media {r['id']}: {e}")

            # Fingerprint music
            cursor = await db.execute(
                "SELECT id, title, artist, file_path, file_size, duration FROM music_tracks"
            )
            rows = await cursor.fetchall()
            for r in rows:
                r = row_to_dict(r)
                fp = r["file_path"]
                if not fp or not os.path.exists(fp):
                    continue
                try:
                    fhash = await asyncio.to_thread(compute_fingerprint, fp)
                    title_norm = (r.get("title") or "").lower().strip()
                    artist_norm = (r.get("artist") or "").lower().strip()
                    await db.execute(
                        """INSERT INTO content_fingerprints
                               (content_type, content_id, file_hash, file_size, duration,
                                title_normalized, artist_normalized)
                           VALUES (?, ?, ?, ?, ?, ?, ?)
                           ON CONFLICT(content_type, content_id) DO UPDATE SET
                               file_hash = excluded.file_hash,
                               file_size = excluded.file_size,
                               duration = excluded.duration,
                               title_normalized = excluded.title_normalized,
                               artist_normalized = excluded.artist_normalized""",
                        ("music", r["id"], fhash, r.get("file_size", 0),
                         r.get("duration"), title_norm, artist_norm),
                    )
                    count += 1
                except Exception as e:
                    logger.warning(f"Fingerprint failed for track {r['id']}: {e}")

            # Fingerprint books
            cursor = await db.execute(
                "SELECT id, title, author, file_path, file_size FROM books"
            )
            rows = await cursor.fetchall()
            for r in rows:
                r = row_to_dict(r)
                fp = r["file_path"]
                if not fp or not os.path.exists(fp):
                    continue
                try:
                    fhash = await asyncio.to_thread(compute_fingerprint, fp)
                    title_norm = (r.get("title") or "").lower().strip()
                    artist_norm = (r.get("author") or "").lower().strip()
                    await db.execute(
                        """INSERT INTO content_fingerprints
                               (content_type, content_id, file_hash, file_size,
                                title_normalized, artist_normalized)
                           VALUES (?, ?, ?, ?, ?, ?)
                           ON CONFLICT(content_type, content_id) DO UPDATE SET
                               file_hash = excluded.file_hash,
                               file_size = excluded.file_size,
                               title_normalized = excluded.title_normalized,
                               artist_normalized = excluded.artist_normalized""",
                        ("book", r["id"], fhash, r.get("file_size", 0),
                         title_norm, artist_norm),
                    )
                    count += 1
                except Exception as e:
                    logger.warning(f"Fingerprint failed for book {r['id']}: {e}")

            await db.commit()
            logger.info(f"Fingerprinting complete: {count} items processed")
        except Exception as e:
            logger.error(f"Fingerprinting task failed: {e}")
        finally:
            await db.close()

    asyncio.create_task(_run_fingerprinting())
    return {"status": "fingerprinting_started"}


@router.get("/fingerprints")
async def list_fingerprints(
    content_type: Optional[str] = None,
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
):
    """List fingerprints with pagination."""
    db = await get_db()
    try:
        conditions = []
        params: list = []
        if content_type:
            conditions.append("content_type = ?")
            params.append(content_type)

        where = (" WHERE " + " AND ".join(conditions)) if conditions else ""

        cursor = await db.execute(
            f"SELECT COUNT(*) as cnt FROM content_fingerprints{where}", params
        )
        total = (await cursor.fetchone())["cnt"]

        cursor = await db.execute(
            f"SELECT * FROM content_fingerprints{where} ORDER BY created_at DESC LIMIT ? OFFSET ?",
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


# ===========================================================================
# LIBRARY DIFF
# ===========================================================================

@router.post("/diff")
async def library_diff(data: DiffRequest):
    """Device sends its fingerprints; server returns what differs."""
    db = await get_db()
    try:
        # Verify device exists
        cursor = await db.execute("SELECT id FROM devices WHERE id = ?", (data.device_id,))
        if not await cursor.fetchone():
            raise HTTPException(404, "Device not found")

        # Build device fingerprint lookup: (content_type, content_id) -> file_hash
        device_fps: dict[tuple[str, int], str] = {}
        for fp in data.fingerprints:
            key = (fp.get("content_type", ""), fp.get("content_id", 0))
            device_fps[key] = fp.get("file_hash", "")

        # Load all server fingerprints
        cursor = await db.execute(
            "SELECT content_type, content_id, file_hash, file_size, title_normalized FROM content_fingerprints"
        )
        server_rows = await cursor.fetchall()

        server_fps: dict[tuple[str, int], dict] = {}
        for r in server_rows:
            rd = row_to_dict(r)
            key = (rd["content_type"], rd["content_id"])
            server_fps[key] = rd

        # Compute diff
        server_has_not_device = []  # On server, not on device
        device_has_not_server = []  # On device, not on server
        matched = []               # Same content, same hash

        for key, srv in server_fps.items():
            if key not in device_fps:
                server_has_not_device.append(srv)
            elif device_fps[key] == srv["file_hash"]:
                matched.append(srv)
            else:
                # Hash mismatch — treat as server having a different version
                server_has_not_device.append(srv)

        for key, dev_hash in device_fps.items():
            if key not in server_fps:
                device_has_not_server.append({
                    "content_type": key[0],
                    "content_id": key[1],
                    "file_hash": dev_hash,
                })

        return {
            "server_has_not_device": server_has_not_device,
            "device_has_not_server": device_has_not_server,
            "matched": matched,
            "summary": {
                "server_only": len(server_has_not_device),
                "device_only": len(device_has_not_server),
                "matched": len(matched),
            },
        }
    finally:
        await db.close()


# ===========================================================================
# DOWNLOADS
# ===========================================================================

@router.post("/downloads")
async def enqueue_downloads(data: DownloadEnqueue):
    """Enqueue download jobs, create transfer_job records, return download URLs."""
    db = await get_db()
    try:
        # Verify device
        cursor = await db.execute("SELECT id FROM devices WHERE id = ?", (data.device_id,))
        if not await cursor.fetchone():
            raise HTTPException(404, "Device not found")

        jobs = []
        for item in data.items:
            ct = item.get("content_type", "movie")
            cid = item.get("content_id")
            if cid is None:
                continue

            # Look up actual file info
            info = await _lookup_file_path(db, ct, cid)
            job_id = str(uuid.uuid4())
            file_name = os.path.basename(info["file_path"])

            await db.execute(
                """INSERT INTO transfer_jobs
                       (id, job_type, status, source_device_id, target_device_id,
                        content_type, content_id, file_name, file_size, priority, created_at)
                   VALUES (?, 'download', 'queued', 'server', ?, ?, ?, ?, ?, ?, datetime('now'))""",
                (job_id, data.device_id, ct, cid, file_name,
                 info.get("file_size", 0), data.priority),
            )

            # Record in device_library as pending
            await db.execute(
                """INSERT OR IGNORE INTO device_library
                       (device_id, content_type, content_id, local_file_size, downloaded_at)
                   VALUES (?, ?, ?, 0, NULL)""",
                (data.device_id, ct, cid),
            )

            jobs.append({
                "job_id": job_id,
                "content_type": ct,
                "content_id": cid,
                "file_name": file_name,
                "file_size": info.get("file_size", 0),
                "download_url": f"/api/sync/downloads/{job_id}/file",
                "status": "queued",
            })

        await db.commit()
        return {"jobs": jobs, "total": len(jobs)}
    finally:
        await db.close()


@router.get("/downloads/{device_id}")
async def list_device_downloads(
    device_id: str,
    status: Optional[str] = None,
    limit: int = Query(50, ge=1, le=500),
    offset: int = Query(0, ge=0),
):
    """List download jobs for a device."""
    db = await get_db()
    try:
        conditions = ["target_device_id = ?", "job_type = 'download'"]
        params: list = [device_id]
        if status:
            conditions.append("status = ?")
            params.append(status)

        where = " WHERE " + " AND ".join(conditions)

        cursor = await db.execute(
            f"SELECT COUNT(*) as cnt FROM transfer_jobs{where}", params
        )
        total = (await cursor.fetchone())["cnt"]

        cursor = await db.execute(
            f"SELECT * FROM transfer_jobs{where} ORDER BY created_at DESC LIMIT ? OFFSET ?",
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


@router.patch("/downloads/{job_id}")
async def update_download(job_id: str, data: DownloadUpdate):
    """Pause/resume/cancel a download, or update progress."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM transfer_jobs WHERE id = ?", (job_id,))
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Job not found")

        job = row_to_dict(row)
        updates = []
        params: list = []

        if data.status is not None:
            valid_transitions = {
                "queued": ["downloading", "cancelled"],
                "downloading": ["paused", "cancelled", "completed", "error"],
                "paused": ["queued", "cancelled"],
            }
            allowed = valid_transitions.get(job["status"], [])
            if data.status not in allowed and data.status != job["status"]:
                raise HTTPException(
                    400,
                    f"Cannot transition from '{job['status']}' to '{data.status}'. "
                    f"Allowed: {allowed}",
                )
            updates.append("status = ?")
            params.append(data.status)

            if data.status == "downloading" and not job.get("started_at"):
                updates.append("started_at = datetime('now')")
            if data.status == "completed":
                updates.append("completed_at = datetime('now')")
            if data.status == "cancelled":
                updates.append("completed_at = datetime('now')")

        if data.bytes_transferred is not None:
            updates.append("bytes_transferred = ?")
            params.append(data.bytes_transferred)

        if not updates:
            return row_to_dict(row)

        params.append(job_id)
        await db.execute(
            f"UPDATE transfer_jobs SET {', '.join(updates)} WHERE id = ?", params
        )
        await db.commit()

        # If completed, update device_library
        if data.status == "completed":
            fp_hash = None
            cursor = await db.execute(
                "SELECT file_hash FROM content_fingerprints WHERE content_type = ? AND content_id = ?",
                (job["content_type"], job["content_id"]),
            )
            fp_row = await cursor.fetchone()
            if fp_row:
                fp_hash = fp_row["file_hash"]

            await db.execute(
                """INSERT OR REPLACE INTO device_library
                       (device_id, content_type, content_id, fingerprint_hash,
                        local_file_size, downloaded_at)
                   VALUES (?, ?, ?, ?, ?, datetime('now'))""",
                (job["target_device_id"], job["content_type"],
                 job["content_id"], fp_hash, job["file_size"]),
            )
            await db.commit()

        cursor = await db.execute("SELECT * FROM transfer_jobs WHERE id = ?", (job_id,))
        return row_to_dict(await cursor.fetchone())
    finally:
        await db.close()


@router.get("/downloads/{job_id}/file")
async def download_file(job_id: str, request: Request):
    """Actual file download with HTTP Range support."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM transfer_jobs WHERE id = ?", (job_id,)
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Job not found")

        job = row_to_dict(row)
        if job["status"] == "cancelled":
            raise HTTPException(410, "Download was cancelled")

        # Mark as downloading if queued
        if job["status"] == "queued":
            await db.execute(
                "UPDATE transfer_jobs SET status = 'downloading', started_at = datetime('now') WHERE id = ?",
                (job_id,),
            )
            await db.commit()

        # Look up actual file path from content table
        info = await _lookup_file_path(db, job["content_type"], job["content_id"])
        file_path = info["file_path"]
    finally:
        await db.close()

    if not os.path.exists(file_path):
        raise HTTPException(404, f"File not found on disk")

    file_size = os.path.getsize(file_path)
    ext = Path(file_path).suffix.lower()

    content_types = {
        ".mp4": "video/mp4", ".mkv": "video/x-matroska", ".avi": "video/x-msvideo",
        ".mov": "video/quicktime", ".m4v": "video/mp4", ".webm": "video/webm",
        ".mp3": "audio/mpeg", ".flac": "audio/flac", ".m4a": "audio/mp4",
        ".aac": "audio/aac", ".ogg": "audio/ogg", ".wav": "audio/wav",
        ".epub": "application/epub+zip", ".pdf": "application/pdf",
        ".mobi": "application/x-mobipocket-ebook",
    }
    content_type = content_types.get(ext, "application/octet-stream")

    range_header = request.headers.get("range")

    if range_header:
        range_spec = range_header.replace("bytes=", "")
        parts = range_spec.split("-")
        start = int(parts[0]) if parts[0] else 0
        end = int(parts[1]) if len(parts) > 1 and parts[1] else file_size - 1
        end = min(end, file_size - 1)
        chunk_size = end - start + 1

        async def ranged_file():
            with open(file_path, "rb") as f:
                f.seek(start)
                remaining = chunk_size
                while remaining > 0:
                    read_size = min(remaining, 1024 * 1024)  # 1MB chunks
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
                "Content-Disposition": f'attachment; filename="{os.path.basename(file_path)}"',
            },
        )
    else:
        return FileResponse(
            file_path,
            media_type=content_type,
            headers={
                "Accept-Ranges": "bytes",
                "Content-Length": str(file_size),
                "Content-Disposition": f'attachment; filename="{os.path.basename(file_path)}"',
            },
        )


# ===========================================================================
# UPLOADS
# ===========================================================================

@router.post("/uploads/prepare")
async def prepare_upload(data: UploadPrepare):
    """Dedup check against fingerprints. Returns job_id if upload needed."""
    db = await get_db()
    try:
        # Check for existing fingerprint match
        cursor = await db.execute(
            "SELECT content_type, content_id, file_hash FROM content_fingerprints WHERE file_hash = ?",
            (data.file_hash,),
        )
        existing = await cursor.fetchone()
        if existing:
            e = row_to_dict(existing)
            return {
                "status": "duplicate",
                "existing_content_type": e["content_type"],
                "existing_content_id": e["content_id"],
                "message": "File already exists in library",
            }

        # Create an upload job
        job_id = str(uuid.uuid4())
        meta = json.dumps(data.metadata or {})
        await db.execute(
            """INSERT INTO transfer_jobs
                   (id, job_type, status, source_device_id, target_device_id,
                    content_type, content_id, file_name, file_size, metadata, created_at)
               VALUES (?, 'upload', 'queued', ?, 'server', ?, NULL, ?, ?, ?, datetime('now'))""",
            (job_id, data.device_id, data.content_type, data.file_name,
             data.file_size, meta),
        )
        await db.commit()

        return {
            "status": "ready",
            "job_id": job_id,
            "upload_url": f"/api/sync/uploads/{job_id}",
        }
    finally:
        await db.close()


@router.post("/uploads/{job_id}")
async def receive_upload(job_id: str, file: UploadFile = File(...)):
    """Receive an uploaded file (multipart)."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM transfer_jobs WHERE id = ? AND job_type = 'upload'",
            (job_id,),
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Upload job not found")

        job = row_to_dict(row)
        if job["status"] not in ("queued", "uploading"):
            raise HTTPException(400, f"Upload job is '{job['status']}', cannot receive file")

        # Mark as uploading
        await db.execute(
            "UPDATE transfer_jobs SET status = 'uploading', started_at = datetime('now') WHERE id = ?",
            (job_id,),
        )
        await db.commit()
    finally:
        await db.close()

    # Save to UPLOAD_DIR with sanitized filename
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    safe_name = os.path.basename(job['file_name'])
    dest = UPLOAD_DIR / f"{job_id}_{safe_name}"
    # Verify the resolved dest stays within UPLOAD_DIR
    if not os.path.realpath(str(dest)).startswith(os.path.realpath(str(UPLOAD_DIR)) + os.sep):
        raise HTTPException(400, "Invalid file name")
    total_written = 0
    try:
        with open(dest, "wb") as f:
            while True:
                chunk = await file.read(1024 * 1024)  # 1MB at a time
                if not chunk:
                    break
                f.write(chunk)
                total_written += len(chunk)
    except Exception as e:
        # Clean up partial file
        if dest.exists():
            dest.unlink()
        db = await get_db()
        try:
            await db.execute(
                "UPDATE transfer_jobs SET status = 'error', error_message = ? WHERE id = ?",
                (str(e), job_id),
            )
            await db.commit()
        finally:
            await db.close()
        logger.error(f"Upload failed for job {job_id}: {e}")
        raise HTTPException(500, "Upload failed")

    # Update job with bytes written
    db = await get_db()
    try:
        await db.execute(
            "UPDATE transfer_jobs SET bytes_transferred = ?, status = 'uploaded' WHERE id = ?",
            (total_written, job_id),
        )
        await db.commit()
    finally:
        await db.close()

    return {
        "job_id": job_id,
        "bytes_received": total_written,
        "status": "uploaded",
        "complete_url": f"/api/sync/uploads/{job_id}/complete",
    }


@router.post("/uploads/{job_id}/complete")
async def complete_upload(job_id: str, data: UploadComplete):
    """Verify hash and mark upload as complete for library ingestion."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM transfer_jobs WHERE id = ? AND job_type = 'upload'",
            (job_id,),
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Upload job not found")

        job = row_to_dict(row)
        if job["status"] != "uploaded":
            raise HTTPException(400, f"Upload job is '{job['status']}', expected 'uploaded'")

        # Verify file exists on disk (use sanitized filename)
        safe_name = os.path.basename(job['file_name'])
        dest = UPLOAD_DIR / f"{job_id}_{safe_name}"
        if not dest.exists():
            raise HTTPException(404, "Uploaded file not found on disk")

        # Compute fingerprint and verify
        actual_hash = await asyncio.to_thread(compute_fingerprint, str(dest))
        if actual_hash != data.file_hash:
            raise HTTPException(
                400,
                f"Hash mismatch: expected {data.file_hash}, got {actual_hash}",
            )

        # Register fingerprint
        file_size = dest.stat().st_size
        await db.execute(
            """INSERT INTO content_fingerprints
                   (content_type, content_id, file_hash, file_size, title_normalized)
               VALUES (?, NULL, ?, ?, ?)
               ON CONFLICT DO NOTHING""",
            (job["content_type"], actual_hash, file_size,
             job["file_name"].lower()),
        )

        # Mark job complete
        await db.execute(
            "UPDATE transfer_jobs SET status = 'completed', completed_at = datetime('now') WHERE id = ?",
            (job_id,),
        )
        await db.commit()

        return {
            "job_id": job_id,
            "status": "completed",
            "file_hash": actual_hash,
            "file_size": file_size,
            "file_path": str(dest),
            "message": "Upload verified and ingested. Add to library via scan or manual import.",
        }
    finally:
        await db.close()


# ===========================================================================
# DEVICE-TO-DEVICE TRANSFERS
# ===========================================================================

@router.post("/transfers")
async def create_transfer(data: TransferCreate):
    """Create a device-to-device transfer via the server."""
    db = await get_db()
    try:
        # Verify both devices exist
        for did in (data.source_device_id, data.target_device_id):
            cursor = await db.execute("SELECT id FROM devices WHERE id = ?", (did,))
            if not await cursor.fetchone():
                raise HTTPException(404, f"Device '{did}' not found")

        if data.source_device_id == data.target_device_id:
            raise HTTPException(400, "Source and target device cannot be the same")

        # Look up content info
        info = await _lookup_file_path(db, data.content_type, data.content_id)

        transfer_id = str(uuid.uuid4())
        file_name = os.path.basename(info["file_path"])

        await db.execute(
            """INSERT INTO transfer_jobs
                   (id, job_type, status, source_device_id, target_device_id,
                    content_type, content_id, file_name, file_size, priority, created_at)
               VALUES (?, 'transfer', 'queued', ?, ?, ?, ?, ?, ?, ?, datetime('now'))""",
            (transfer_id, data.source_device_id, data.target_device_id,
             data.content_type, data.content_id, file_name,
             info.get("file_size", 0), data.priority),
        )
        await db.commit()

        return {
            "transfer_id": transfer_id,
            "status": "queued",
            "source_device_id": data.source_device_id,
            "target_device_id": data.target_device_id,
            "content_type": data.content_type,
            "content_id": data.content_id,
            "file_name": file_name,
            "file_size": info.get("file_size", 0),
        }
    finally:
        await db.close()


@router.get("/transfers/{transfer_id}")
async def get_transfer(transfer_id: str):
    """Get transfer status."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM transfer_jobs WHERE id = ?", (transfer_id,)
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Transfer not found")

        job = row_to_dict(row)
        # Parse metadata if present
        if job.get("metadata"):
            try:
                job["metadata"] = json.loads(job["metadata"])
            except (json.JSONDecodeError, TypeError):
                pass

        # Compute progress percentage
        if job["file_size"] and job["file_size"] > 0:
            job["progress_pct"] = round(
                (job["bytes_transferred"] / job["file_size"]) * 100, 1
            )
        else:
            job["progress_pct"] = 0.0

        return job
    finally:
        await db.close()
