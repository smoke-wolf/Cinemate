"""
Cinemate Media Server
=====================
Personal media library server with LAN discovery, streaming, and multi-account support.

Start: python3 -m uvicorn main:app --host 0.0.0.0 --port 9876 --reload
Docs:  http://localhost:9876/docs
"""

import asyncio
import hashlib
import json
import logging
import os
import socket
import time
import uuid
from contextlib import asynccontextmanager
from datetime import datetime
from pathlib import Path
from typing import Optional

from fastapi import (
    FastAPI,
    HTTPException,
    Query,
    WebSocket,
    WebSocketDisconnect,
    Request,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, StreamingResponse, Response
from pydantic import BaseModel

from database import get_db, init_db, load_config, save_config, THUMBNAIL_DIR
from scanner import scan_directory, scan_state, parse_filename
from wan_routes import router as wan_router
from music_routes import router as music_router
from book_routes import router as book_router
from sync_routes import router as sync_router
from transcode import router as transcode_router
from middleware import WANSecurityMiddleware

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("cinemate")

# ---------------------------------------------------------------------------
# Version / metadata
# ---------------------------------------------------------------------------
VERSION = "1.0.0"
DEFAULT_PORT = 9876

# ---------------------------------------------------------------------------
# mDNS / Bonjour
# ---------------------------------------------------------------------------
_zeroconf_instance = None
_service_info = None


def get_lan_ip() -> str:
    """Get the primary LAN IP address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def start_mdns(port: int, server_name: str):
    """Advertise the server via mDNS/Bonjour."""
    global _zeroconf_instance, _service_info
    try:
        from zeroconf import Zeroconf, ServiceInfo
        import socket as _socket

        ip = get_lan_ip()
        _service_info = ServiceInfo(
            "_cinemate._tcp.local.",
            f"{server_name}._cinemate._tcp.local.",
            addresses=[_socket.inet_aton(ip)],
            port=port,
            properties={
                "version": VERSION,
                "name": server_name,
            },
            server=f"{_socket.gethostname()}.local.",
        )
        _zeroconf_instance = Zeroconf()
        _zeroconf_instance.register_service(_service_info)
        logger.info(f"mDNS registered: {server_name} at {ip}:{port}")
    except Exception as e:
        logger.warning(f"mDNS registration failed (non-fatal): {e}")


def stop_mdns():
    """Unregister mDNS service."""
    global _zeroconf_instance, _service_info
    try:
        if _zeroconf_instance and _service_info:
            _zeroconf_instance.unregister_service(_service_info)
            _zeroconf_instance.close()
            logger.info("mDNS unregistered")
    except Exception:
        pass


def check_firewall() -> bool:
    """Check if macOS Application Firewall is enabled and warn if it may block connections."""
    import platform
    import subprocess

    if platform.system() != "Darwin":
        return True

    try:
        result = subprocess.run(
            ["/usr/libexec/ApplicationFirewall/socketfilterfw", "--getglobalstate"],
            capture_output=True, text=True, timeout=5,
        )
        if "enabled" in result.stdout.lower():
            logger.warning("macOS Firewall is ON — LAN clients may be blocked.")
            logger.warning("  Fix: System Settings → Network → Firewall → allow Cinemate/Python")
            logger.warning("  Or run: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off")
            return False
        return True
    except Exception:
        return True


# ---------------------------------------------------------------------------
# WebSocket manager
# ---------------------------------------------------------------------------
class ConnectionManager:
    """Manages WebSocket connections for real-time updates."""

    def __init__(self):
        self.active: dict[str, WebSocket] = {}  # client_id -> ws

    async def connect(self, websocket: WebSocket, client_id: str):
        await websocket.accept()
        self.active[client_id] = websocket
        logger.info(f"WS connected: {client_id} ({len(self.active)} total)")

    def disconnect(self, client_id: str):
        self.active.pop(client_id, None)
        logger.info(f"WS disconnected: {client_id} ({len(self.active)} total)")

    async def broadcast(self, message: dict):
        dead = []
        for cid, ws in self.active.items():
            try:
                await ws.send_json(message)
            except Exception:
                dead.append(cid)
        for cid in dead:
            self.active.pop(cid, None)

    @property
    def count(self) -> int:
        return len(self.active)


ws_manager = ConnectionManager()

# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------


class ScanRequest(BaseModel):
    path: str


class AccountCreate(BaseModel):
    name: str
    avatar_color: str = "#6366f1"
    pin: Optional[str] = None


class AccountUpdate(BaseModel):
    name: Optional[str] = None
    avatar_color: Optional[str] = None
    pin: Optional[str] = None


class WatchProgressUpdate(BaseModel):
    position: float  # seconds
    duration: Optional[float] = None


class WatchedUpdate(BaseModel):
    watched: bool = True


class ServerSettingsUpdate(BaseModel):
    server_name: Optional[str] = None
    port: Optional[int] = None
    allowed_ips: Optional[list[str]] = None
    require_pin: Optional[bool] = None
    access_mode: Optional[str] = None


class AccessRulesUpdate(BaseModel):
    access_mode: str = "lan"  # "lan" or "specific_ips"
    allowed_ips: list[str] = []
    require_pin: bool = False


# ---------------------------------------------------------------------------
# Lifespan
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup / shutdown logic."""
    await init_db()
    cfg = load_config()
    port = cfg.get("port", DEFAULT_PORT)
    name = cfg.get("server_name", "Cinemate Server")
    ip = get_lan_ip()

    wan_enabled = cfg.get("wan_enabled", False)

    firewall_ok = await asyncio.to_thread(check_firewall)

    logger.info("=" * 50)
    logger.info(f"  Cinemate Media Server v{VERSION}")
    logger.info(f"  Local:   http://127.0.0.1:{port}")
    logger.info(f"  LAN:     http://{ip}:{port}")
    logger.info(f"  WAN:     {'enabled' if wan_enabled else 'disabled'}")
    logger.info(f"  Firewall: {'OK' if firewall_ok else 'BLOCKING — see warnings above'}")
    logger.info(f"  Docs:    http://127.0.0.1:{port}/docs")
    logger.info("=" * 50)

    await asyncio.to_thread(start_mdns, port, name)

    from transcode import precache_faststart_all
    asyncio.create_task(precache_faststart_all())

    yield

    # Stop any active tunnel on shutdown
    from tunnel import tunnel_manager
    await tunnel_manager.stop()

    await asyncio.to_thread(stop_mdns)
    logger.info("Cinemate server stopped.")


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Cinemate Media Server",
    description="Personal media library server with LAN streaming and multi-account support.",
    version=VERSION,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# WAN security middleware (rate limiting, IP filter, request logging)
app.add_middleware(WANSecurityMiddleware)

# WAN routes (tunnel management, admin auth, domain config)
app.include_router(wan_router)

# Music library routes (tracks, albums, artists, playlists, streaming)
app.include_router(music_router)

# Book library routes (e-books, PDFs, reading progress, bookmarks)
app.include_router(book_router)

# Sync, download, upload, and device management routes
app.include_router(sync_router)

# Video transcoding routes (iOS compatibility, codec conversion, cache)
app.include_router(transcode_router)


# ---------------------------------------------------------------------------
# Helper: hash a pin
# ---------------------------------------------------------------------------
def hash_pin(pin: str) -> str:
    return hashlib.sha256(pin.encode()).hexdigest()


# ---------------------------------------------------------------------------
# Helper: row -> dict
# ---------------------------------------------------------------------------
def row_to_dict(row) -> dict:
    if row is None:
        return {}
    return dict(row)


# ===========================================================================
# 1. LIBRARY MANAGEMENT
# ===========================================================================

@app.get("/api/library")
async def list_library(
    search: Optional[str] = None,
    sort: str = Query("date_added", pattern="^(title|year|date_added|file_size|duration|rating)$"),
    order: str = Query("desc", pattern="^(asc|desc)$"),
    genre: Optional[str] = None,
    quality: Optional[str] = None,
    media_type: Optional[str] = None,
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
):
    """List all media with filtering, sorting, and pagination."""
    db = await get_db()
    try:
        conditions = []
        params = []

        if search:
            conditions.append("(title LIKE ? OR show_name LIKE ?)")
            params.extend([f"%{search}%", f"%{search}%"])
        if genre:
            conditions.append("genre LIKE ?")
            params.append(f"%{genre}%")
        if quality:
            conditions.append("quality = ?")
            params.append(quality)
        if media_type:
            conditions.append("media_type = ?")
            params.append(media_type)

        where = " WHERE " + " AND ".join(conditions) if conditions else ""
        order_clause = f" ORDER BY {sort} {order.upper()}"

        # Total count
        cursor = await db.execute(f"SELECT COUNT(*) as cnt FROM media{where}", params)
        total = (await cursor.fetchone())["cnt"]

        # Fetch page
        cursor = await db.execute(
            f"SELECT * FROM media{where}{order_clause} LIMIT ? OFFSET ?",
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


# NOTE: Specific /api/library/* routes MUST come before /api/library/{media_id}
# to avoid FastAPI matching "scan", "genres", "stats" as media_id.

@app.post("/api/library/scan")
async def start_scan(req: ScanRequest):
    """Trigger a directory scan in the background."""
    path = req.path
    if not os.path.isdir(path):
        raise HTTPException(400, f"Directory not found: {path}")
    if scan_state.scanning:
        raise HTTPException(409, "Scan already in progress")

    asyncio.create_task(scan_directory(path, ws_broadcast=ws_manager.broadcast))
    return {"status": "scan_started", "path": path}


@app.get("/api/library/scan/status")
async def get_scan_status():
    """Get current scan progress."""
    return scan_state.to_dict()


@app.get("/api/library/genres")
async def get_genres():
    """Genre breakdown with counts."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT genre, COUNT(*) as count FROM media WHERE genre IS NOT NULL "
            "AND genre != '' AND media_type = 'movie' GROUP BY genre ORDER BY count DESC"
        )
        rows = await cursor.fetchall()
        return {"genres": [row_to_dict(r) for r in rows]}
    finally:
        await db.close()


@app.post("/api/library/enrich-genres")
async def enrich_movie_genres():
    """Look up genres for movies missing them using OMDb API."""
    import aiohttp
    import re

    OMDB_URL = "http://www.omdbapi.com/"
    OMDB_KEY = "trilogy"

    db = await get_db()
    updated = 0
    checked = 0
    try:
        cursor = await db.execute(
            "SELECT id, title, year FROM media WHERE media_type = 'movie' "
            "AND (genre IS NULL OR genre = '')"
        )
        movies = await cursor.fetchall()
        checked = len(movies)

        async with aiohttp.ClientSession() as session:
            for row in movies:
                mid, title, year = row["id"], row["title"], row["year"]
                clean = re.sub(r'\s*[-_(]\s*(RBG|Blackjesus|iFT|MAXSPEED|BOKUTOX|HANDJOB|JYK|aXXo|anoXmous|VoStFr|AAC\d*[\s.]?\d*|720p?|1080p?|BluRay|BRRip|HDRip|WEBRip|DvDrip|XviD|x264|x265|HEVC|DTS|YIFY|RARBG|T\d+).*$', '', title, flags=re.IGNORECASE).strip()
                clean = re.sub(r'\s+XviD.*$', '', clean, flags=re.IGNORECASE)
                clean = re.sub(r'\s+AAC\d.*$', '', clean, flags=re.IGNORECASE)
                clean = re.sub(r'\s+www\s.*$', '', clean, flags=re.IGNORECASE)
                clean = re.sub(r'\s+\d{3,4}$', '', clean)
                clean = re.sub(r'([a-z])([A-Z])', r'\1 \2', clean)

                params = {"apikey": OMDB_KEY, "t": clean, "type": "movie"}
                if year:
                    params["y"] = year

                try:
                    async with session.get(OMDB_URL, params=params, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                        if resp.status != 200:
                            continue
                        data = await resp.json()

                    if data.get("Response") == "True" and data.get("Genre") and data["Genre"] != "N/A":
                        await db.execute("UPDATE media SET genre = ? WHERE id = ?", (data["Genre"], mid))
                        updated += 1

                    await asyncio.sleep(0.15)
                except Exception:
                    continue

        await db.commit()
    finally:
        await db.close()

    return {"updated": updated, "total_checked": checked}


@app.get("/api/library/stats")
async def get_library_stats():
    """Library-wide statistics."""
    db = await get_db()
    try:
        stats = {}
        cursor = await db.execute("SELECT COUNT(*) as total FROM media")
        stats["total_items"] = (await cursor.fetchone())["total"]

        cursor = await db.execute("SELECT COUNT(*) as c FROM media WHERE media_type = 'movie'")
        stats["movies"] = (await cursor.fetchone())["c"]

        cursor = await db.execute("SELECT COUNT(*) as c FROM media WHERE media_type = 'tv'")
        stats["tv_episodes"] = (await cursor.fetchone())["c"]

        cursor = await db.execute("SELECT COUNT(DISTINCT show_name) as c FROM media WHERE show_name IS NOT NULL")
        stats["tv_shows"] = (await cursor.fetchone())["c"]

        cursor = await db.execute("SELECT COALESCE(SUM(duration), 0) as d FROM media")
        total_seconds = (await cursor.fetchone())["d"]
        stats["total_duration_seconds"] = total_seconds
        stats["total_duration_hours"] = round(total_seconds / 3600, 1)

        cursor = await db.execute("SELECT COALESCE(SUM(file_size), 0) as s FROM media")
        total_bytes = (await cursor.fetchone())["s"]
        stats["total_size_bytes"] = total_bytes
        stats["total_size_gb"] = round(total_bytes / (1024 ** 3), 2)

        cursor = await db.execute(
            "SELECT quality, COUNT(*) as count FROM media WHERE quality IS NOT NULL "
            "GROUP BY quality ORDER BY count DESC"
        )
        stats["quality_breakdown"] = [row_to_dict(r) for r in await cursor.fetchall()]

        cursor = await db.execute(
            "SELECT format, COUNT(*) as count FROM media GROUP BY format ORDER BY count DESC"
        )
        stats["format_breakdown"] = [row_to_dict(r) for r in await cursor.fetchall()]

        return stats
    finally:
        await db.close()


@app.get("/api/library/{media_id}")
async def get_media(media_id: int):
    """Get details for a single media item."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM media WHERE id = ?", (media_id,))
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Media not found")
        return row_to_dict(row)
    finally:
        await db.close()


@app.get("/api/shows")
async def get_shows():
    """TV shows grouped by show name with seasons/episodes."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM media WHERE media_type = 'tv' AND show_name IS NOT NULL "
            "ORDER BY show_name, season_number, episode_number"
        )
        rows = await cursor.fetchall()

        shows: dict = {}
        for row in rows:
            r = row_to_dict(row)
            name = r["show_name"]
            if name not in shows:
                shows[name] = {"show_name": name, "seasons": {}}
            season = r.get("season_number") or 0
            season_key = str(season)
            if season_key not in shows[name]["seasons"]:
                shows[name]["seasons"][season_key] = []
            shows[name]["seasons"][season_key].append(r)

        # Convert to list
        result = []
        for name, data in shows.items():
            seasons_list = []
            for snum, episodes in sorted(data["seasons"].items(), key=lambda x: int(x[0])):
                seasons_list.append({
                    "season_number": int(snum),
                    "episodes": episodes,
                    "episode_count": len(episodes),
                })
            result.append({
                "show_name": name,
                "seasons": seasons_list,
                "total_episodes": sum(s["episode_count"] for s in seasons_list),
                "total_seasons": len(seasons_list),
            })

        return {"shows": result}
    finally:
        await db.close()


# ===========================================================================
# 2. USER ACCOUNTS
# ===========================================================================

@app.post("/api/accounts", status_code=201)
async def create_account(data: AccountCreate):
    """Create a new user account."""
    db = await get_db()
    try:
        pin_h = hash_pin(data.pin) if data.pin else None
        try:
            cursor = await db.execute(
                "INSERT INTO accounts (name, avatar_color, pin_hash) VALUES (?, ?, ?)",
                (data.name, data.avatar_color, pin_h),
            )
            await db.commit()
            return {
                "id": cursor.lastrowid,
                "name": data.name,
                "avatar_color": data.avatar_color,
                "has_pin": pin_h is not None,
            }
        except Exception as e:
            if "UNIQUE" in str(e):
                raise HTTPException(409, f"Account '{data.name}' already exists")
            raise
    finally:
        await db.close()


@app.get("/api/accounts")
async def list_accounts():
    """List all accounts (pin hashes excluded)."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT id, name, avatar_color, pin_hash, created_at FROM accounts ORDER BY id")
        rows = await cursor.fetchall()
        result = []
        for r in rows:
            d = row_to_dict(r)
            d["has_pin"] = d.pop("pin_hash") is not None
            result.append(d)
        return {"accounts": result}
    finally:
        await db.close()


@app.put("/api/accounts/{account_id}")
async def update_account(account_id: int, data: AccountUpdate):
    """Update an account."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM accounts WHERE id = ?", (account_id,))
        if not await cursor.fetchone():
            raise HTTPException(404, "Account not found")

        updates = []
        params = []
        if data.name is not None:
            updates.append("name = ?")
            params.append(data.name)
        if data.avatar_color is not None:
            updates.append("avatar_color = ?")
            params.append(data.avatar_color)
        if data.pin is not None:
            updates.append("pin_hash = ?")
            params.append(hash_pin(data.pin) if data.pin else None)

        if updates:
            params.append(account_id)
            await db.execute(
                f"UPDATE accounts SET {', '.join(updates)} WHERE id = ?", params
            )
            await db.commit()

        cursor = await db.execute(
            "SELECT id, name, avatar_color, pin_hash, created_at FROM accounts WHERE id = ?",
            (account_id,),
        )
        row = row_to_dict(await cursor.fetchone())
        row["has_pin"] = row.pop("pin_hash") is not None
        return row
    finally:
        await db.close()


@app.delete("/api/accounts/{account_id}")
async def delete_account(account_id: int):
    """Delete an account and all associated data."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT id FROM accounts WHERE id = ?", (account_id,))
        if not await cursor.fetchone():
            raise HTTPException(404, "Account not found")
        await db.execute("DELETE FROM accounts WHERE id = ?", (account_id,))
        await db.commit()
        return {"deleted": account_id}
    finally:
        await db.close()


# ===========================================================================
# 3. PER-ACCOUNT ACTIONS
# ===========================================================================

async def _ensure_account_media(db, account_id: int, media_id: int):
    """Ensure account and media exist; create account_media row if needed."""
    cursor = await db.execute("SELECT id FROM accounts WHERE id = ?", (account_id,))
    if not await cursor.fetchone():
        raise HTTPException(404, "Account not found")
    cursor = await db.execute("SELECT id FROM media WHERE id = ?", (media_id,))
    if not await cursor.fetchone():
        raise HTTPException(404, "Media not found")
    await db.execute(
        "INSERT OR IGNORE INTO account_media (account_id, media_id) VALUES (?, ?)",
        (account_id, media_id),
    )


@app.post("/api/accounts/{account_id}/favorites/{media_id}")
async def toggle_favorite(account_id: int, media_id: int):
    """Toggle favorite status for a media item."""
    db = await get_db()
    try:
        await _ensure_account_media(db, account_id, media_id)
        cursor = await db.execute(
            "SELECT favorite FROM account_media WHERE account_id = ? AND media_id = ?",
            (account_id, media_id),
        )
        current = (await cursor.fetchone())["favorite"]
        new_val = 0 if current else 1
        await db.execute(
            "UPDATE account_media SET favorite = ? WHERE account_id = ? AND media_id = ?",
            (new_val, account_id, media_id),
        )
        await db.commit()
        return {"account_id": account_id, "media_id": media_id, "favorite": bool(new_val)}
    finally:
        await db.close()


@app.put("/api/accounts/{account_id}/progress/{media_id}")
async def update_watch_progress(account_id: int, media_id: int, data: WatchProgressUpdate):
    """Update watch progress (position in seconds)."""
    db = await get_db()
    try:
        await _ensure_account_media(db, account_id, media_id)

        # Get current state to compute delta
        cursor = await db.execute(
            "SELECT watch_progress, total_watch_time, play_count FROM account_media "
            "WHERE account_id = ? AND media_id = ?",
            (account_id, media_id),
        )
        row = row_to_dict(await cursor.fetchone())
        old_pos = row["watch_progress"] or 0
        delta = max(0, data.position - old_pos)

        now = datetime.utcnow().isoformat()
        play_count = row["play_count"]
        # If position reset to near 0, it's a new play
        if data.position < 5 and old_pos > 60:
            play_count += 1

        await db.execute(
            """UPDATE account_media SET
               watch_progress = ?, total_watch_time = total_watch_time + ?,
               last_played = ?, play_count = ?
               WHERE account_id = ? AND media_id = ?""",
            (data.position, delta, now, play_count, account_id, media_id),
        )
        await db.commit()
        return {
            "account_id": account_id,
            "media_id": media_id,
            "position": data.position,
            "total_watch_time": row["total_watch_time"] + delta,
        }
    finally:
        await db.close()


@app.get("/api/accounts/{account_id}/continue-watching")
async def continue_watching(account_id: int):
    """Get items with partial watch progress."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT id FROM accounts WHERE id = ?", (account_id,))
        if not await cursor.fetchone():
            raise HTTPException(404, "Account not found")

        cursor = await db.execute(
            """SELECT m.*, am.watch_progress, am.last_played, am.total_watch_time
               FROM account_media am
               JOIN media m ON m.id = am.media_id
               WHERE am.account_id = ? AND am.watch_progress > 0 AND am.watched = 0
               ORDER BY am.last_played DESC
               LIMIT 20""",
            (account_id,),
        )
        rows = await cursor.fetchall()
        return {"items": [row_to_dict(r) for r in rows]}
    finally:
        await db.close()


@app.get("/api/accounts/{account_id}/recently-played")
async def recently_played(account_id: int, limit: int = Query(20, ge=1, le=100)):
    """Watch history for an account."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT id FROM accounts WHERE id = ?", (account_id,))
        if not await cursor.fetchone():
            raise HTTPException(404, "Account not found")

        cursor = await db.execute(
            """SELECT m.*, am.watch_progress, am.last_played, am.play_count,
                      am.total_watch_time, am.watched, am.favorite, am.rating
               FROM account_media am
               JOIN media m ON m.id = am.media_id
               WHERE am.account_id = ? AND am.last_played IS NOT NULL
               ORDER BY am.last_played DESC
               LIMIT ?""",
            (account_id, limit),
        )
        rows = await cursor.fetchall()
        return {"items": [row_to_dict(r) for r in rows]}
    finally:
        await db.close()


@app.get("/api/accounts/{account_id}/stats")
async def account_stats(account_id: int):
    """Per-user stats."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT id, name FROM accounts WHERE id = ?", (account_id,))
        acct = await cursor.fetchone()
        if not acct:
            raise HTTPException(404, "Account not found")

        stats = {"account_id": account_id, "account_name": acct["name"]}

        cursor = await db.execute(
            "SELECT COUNT(*) as c FROM account_media WHERE account_id = ? AND watched = 1",
            (account_id,),
        )
        stats["watched_count"] = (await cursor.fetchone())["c"]

        cursor = await db.execute(
            "SELECT COUNT(*) as c FROM account_media WHERE account_id = ? AND favorite = 1",
            (account_id,),
        )
        stats["favorites_count"] = (await cursor.fetchone())["c"]

        cursor = await db.execute(
            "SELECT COALESCE(SUM(total_watch_time), 0) as t FROM account_media WHERE account_id = ?",
            (account_id,),
        )
        total_secs = (await cursor.fetchone())["t"]
        stats["total_watch_time_seconds"] = total_secs
        stats["total_watch_time_hours"] = round(total_secs / 3600, 1)

        cursor = await db.execute(
            "SELECT COALESCE(SUM(play_count), 0) as p FROM account_media WHERE account_id = ?",
            (account_id,),
        )
        stats["total_plays"] = (await cursor.fetchone())["p"]

        return stats
    finally:
        await db.close()


@app.post("/api/accounts/{account_id}/watched/{media_id}")
async def mark_watched(account_id: int, media_id: int, data: WatchedUpdate = WatchedUpdate()):
    """Mark media as watched or unwatched."""
    db = await get_db()
    try:
        await _ensure_account_media(db, account_id, media_id)
        now = datetime.utcnow().isoformat() if data.watched else None
        await db.execute(
            """UPDATE account_media SET watched = ?, last_played = COALESCE(?, last_played)
               WHERE account_id = ? AND media_id = ?""",
            (1 if data.watched else 0, now, account_id, media_id),
        )
        if data.watched:
            await db.execute(
                "UPDATE account_media SET play_count = play_count + 1 WHERE account_id = ? AND media_id = ?",
                (account_id, media_id),
            )
        await db.commit()
        return {"account_id": account_id, "media_id": media_id, "watched": data.watched}
    finally:
        await db.close()


# ===========================================================================
# 4. VIDEO STREAMING
# ===========================================================================

@app.api_route("/api/stream/{media_id}", methods=["GET", "HEAD"])
async def stream_video(media_id: int, request: Request):
    """Stream a video file with HTTP Range support for seeking."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT file_path, format FROM media WHERE id = ?", (media_id,))
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Media not found")
    finally:
        await db.close()

    file_path = row["file_path"]
    if not os.path.exists(file_path):
        raise HTTPException(404, f"File not found on disk: {file_path}")

    file_size = os.path.getsize(file_path)
    ext = Path(file_path).suffix.lower()
    content_types = {
        ".mp4": "video/mp4",
        ".mkv": "video/x-matroska",
        ".avi": "video/x-msvideo",
        ".mov": "video/quicktime",
        ".m4v": "video/mp4",
        ".wmv": "video/x-ms-wmv",
        ".flv": "video/x-flv",
        ".webm": "video/webm",
    }
    content_type = content_types.get(ext, "application/octet-stream")

    if request.method == "HEAD":
        return Response(
            status_code=200,
            headers={
                "Accept-Ranges": "bytes",
                "Content-Length": str(file_size),
                "Content-Type": content_type,
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


@app.get("/api/thumbnail/{media_id}")
async def get_thumbnail(media_id: int):
    """Serve thumbnail image for a media item."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT thumbnail_path FROM media WHERE id = ?", (media_id,)
        )
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Media not found")
    finally:
        await db.close()

    thumb = row["thumbnail_path"]
    if not thumb or not os.path.exists(thumb):
        # Return a placeholder or 404
        raise HTTPException(404, "Thumbnail not available")

    return FileResponse(thumb, media_type="image/jpeg")


# ===========================================================================
# 5. LAN FEATURES
# ===========================================================================

@app.get("/api/server/info")
async def server_info():
    """Server info endpoint."""
    from tunnel import tunnel_manager
    cfg = load_config()
    info = {
        "server_name": cfg.get("server_name", "Cinemate Server"),
        "version": VERSION,
        "ip_address": get_lan_ip(),
        "port": cfg.get("port", DEFAULT_PORT),
        "connected_clients": ws_manager.count,
        "wan_enabled": cfg.get("wan_enabled", False),
    }
    ts = tunnel_manager.status
    if ts.public_url:
        info["public_url"] = ts.public_url
        info["tunnel_type"] = ts.tunnel_type
    return info


@app.get("/api/server/clients")
async def server_clients():
    """List connected WebSocket clients."""
    db = await get_db()
    try:
        cursor = await db.execute(
            """SELECT s.id, s.client_ip, s.client_name, s.connected_at, s.last_activity,
                      m.title as watching_title, m.id as watching_id
               FROM sessions s
               LEFT JOIN media m ON m.id = s.currently_watching
               ORDER BY s.last_activity DESC"""
        )
        rows = await cursor.fetchall()
        return {"clients": [row_to_dict(r) for r in rows]}
    finally:
        await db.close()


@app.put("/api/server/settings")
async def update_server_settings(data: ServerSettingsUpdate):
    """Update server settings."""
    cfg = load_config()
    if data.server_name is not None:
        cfg["server_name"] = data.server_name
    if data.port is not None:
        cfg["port"] = data.port
    if data.allowed_ips is not None:
        cfg["allowed_ips"] = data.allowed_ips
    if data.require_pin is not None:
        cfg["require_pin"] = data.require_pin
    if data.access_mode is not None:
        cfg["access_mode"] = data.access_mode
    save_config(cfg)
    return cfg


# ---------------------------------------------------------------------------
# WebSocket endpoint
# ---------------------------------------------------------------------------

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket for real-time updates (scan progress, new media, etc.)."""
    client_id = str(uuid.uuid4())[:8]
    client_ip = websocket.client.host if websocket.client else "unknown"

    await ws_manager.connect(websocket, client_id)

    # Register session
    db = await get_db()
    try:
        await db.execute(
            "INSERT OR REPLACE INTO sessions (id, client_ip, client_name, connected_at, last_activity) "
            "VALUES (?, ?, ?, datetime('now'), datetime('now'))",
            (client_id, client_ip, f"client-{client_id}"),
        )
        await db.commit()
    finally:
        await db.close()

    try:
        # Send welcome
        await websocket.send_json({
            "type": "connected",
            "client_id": client_id,
            "server_version": VERSION,
        })

        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type", "")

            if msg_type == "ping":
                await websocket.send_json({"type": "pong"})
            elif msg_type == "identify":
                # Client can send its name / account
                db = await get_db()
                try:
                    await db.execute(
                        "UPDATE sessions SET client_name = ?, account_id = ?, last_activity = datetime('now') "
                        "WHERE id = ?",
                        (data.get("client_name", f"client-{client_id}"), data.get("account_id"), client_id),
                    )
                    await db.commit()
                finally:
                    await db.close()
            elif msg_type == "watching":
                # Client reports what they're watching
                db = await get_db()
                try:
                    await db.execute(
                        "UPDATE sessions SET currently_watching = ?, last_activity = datetime('now') WHERE id = ?",
                        (data.get("media_id"), client_id),
                    )
                    await db.commit()
                finally:
                    await db.close()

            elif msg_type == "device_register":
                # Real-time device registration notification
                device_id = data.get("device_id")
                device_name = data.get("name", "Unknown")
                if device_id:
                    db = await get_db()
                    try:
                        now = datetime.utcnow().isoformat()
                        await db.execute(
                            "UPDATE devices SET is_online = 1, last_seen = ? WHERE id = ?",
                            (now, device_id),
                        )
                        await db.commit()
                    finally:
                        await db.close()
                    await ws_manager.broadcast({
                        "type": "device_online",
                        "device_id": device_id,
                        "device_name": device_name,
                        "timestamp": datetime.utcnow().isoformat(),
                    })

            elif msg_type == "device_heartbeat":
                # Device heartbeat via WS
                device_id = data.get("device_id")
                if device_id:
                    db = await get_db()
                    try:
                        now = datetime.utcnow().isoformat()
                        await db.execute(
                            "UPDATE devices SET last_seen = ?, is_online = 1 WHERE id = ?",
                            (now, device_id),
                        )
                        await db.commit()
                    finally:
                        await db.close()
                    await websocket.send_json({"type": "heartbeat_ack", "device_id": device_id})

            elif msg_type == "transfer_progress":
                # Device reports transfer progress
                job_id = data.get("job_id")
                bytes_transferred = data.get("bytes_transferred", 0)
                status = data.get("status")
                if job_id:
                    db = await get_db()
                    try:
                        updates = ["bytes_transferred = ?"]
                        params = [bytes_transferred]
                        if status:
                            updates.append("status = ?")
                            params.append(status)
                        params.append(job_id)
                        await db.execute(
                            f"UPDATE transfer_jobs SET {', '.join(updates)} WHERE id = ?",
                            params,
                        )
                        await db.commit()

                        # Fetch job details for broadcast
                        cursor = await db.execute(
                            "SELECT * FROM transfer_jobs WHERE id = ?", (job_id,)
                        )
                        job_row = await cursor.fetchone()
                    finally:
                        await db.close()

                    if job_row:
                        job_data = dict(job_row)
                        progress_pct = 0.0
                        if job_data["file_size"] and job_data["file_size"] > 0:
                            progress_pct = round(
                                (bytes_transferred / job_data["file_size"]) * 100, 1
                            )

                        # Broadcast progress to all connected clients
                        await ws_manager.broadcast({
                            "type": "transfer_progress",
                            "job_id": job_id,
                            "bytes_transferred": bytes_transferred,
                            "file_size": job_data["file_size"],
                            "progress_pct": progress_pct,
                            "status": job_data["status"],
                        })

                        # If completed, broadcast completion + library update
                        if status == "completed":
                            await ws_manager.broadcast({
                                "type": "transfer_completed",
                                "job_id": job_id,
                                "content_type": job_data["content_type"],
                                "content_id": job_data["content_id"],
                                "target_device_id": job_data["target_device_id"],
                            })
                            await ws_manager.broadcast({
                                "type": "library_updated",
                                "device_id": job_data["target_device_id"],
                                "content_type": job_data["content_type"],
                                "content_id": job_data["content_id"],
                                "action": "downloaded",
                            })

    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.debug(f"WS error for {client_id}: {e}")
    finally:
        ws_manager.disconnect(client_id)
        # Remove session and broadcast device_offline for any linked device
        db = await get_db()
        try:
            await db.execute("DELETE FROM sessions WHERE id = ?", (client_id,))
            await db.commit()
        finally:
            await db.close()

        # Broadcast device_offline if this client had registered a device
        await ws_manager.broadcast({
            "type": "device_offline",
            "client_id": client_id,
            "timestamp": datetime.utcnow().isoformat(),
        })


# ===========================================================================
# 6. LAN ADMIN
# ===========================================================================

@app.get("/api/admin/connections")
async def admin_connections():
    """All active connections with details."""
    db = await get_db()
    try:
        cursor = await db.execute(
            """SELECT s.*, a.name as account_name, m.title as watching_title
               FROM sessions s
               LEFT JOIN accounts a ON a.id = s.account_id
               LEFT JOIN media m ON m.id = s.currently_watching
               ORDER BY s.connected_at DESC"""
        )
        rows = await cursor.fetchall()
        return {
            "connections": [row_to_dict(r) for r in rows],
            "total": len(rows),
        }
    finally:
        await db.close()


@app.post("/api/admin/kick/{client_id}")
async def kick_client(client_id: str):
    """Disconnect a client by closing their WebSocket."""
    ws = ws_manager.active.get(client_id)
    if not ws:
        raise HTTPException(404, "Client not connected")

    try:
        await ws.close(code=4001, reason="Kicked by admin")
    except Exception:
        pass

    ws_manager.disconnect(client_id)

    db = await get_db()
    try:
        await db.execute("DELETE FROM sessions WHERE id = ?", (client_id,))
        await db.commit()
    finally:
        await db.close()

    return {"kicked": client_id}


@app.put("/api/admin/access")
async def update_access_rules(data: AccessRulesUpdate):
    """Configure access rules."""
    cfg = load_config()
    cfg["access_mode"] = data.access_mode
    cfg["allowed_ips"] = data.allowed_ips
    cfg["require_pin"] = data.require_pin
    save_config(cfg)
    return cfg


# ===========================================================================
# Root
# ===========================================================================

@app.get("/health")
async def health():
    return {"status": "ok", "version": VERSION}


@app.get("/api/status")
async def api_status():
    """Alias for server info — iOS app uses this endpoint."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT COUNT(*) as total FROM media")
        media_count = (await cursor.fetchone())["total"]
    finally:
        await db.close()
    cfg = load_config()
    return {
        "name": cfg.get("server_name", "Cinemate Server"),
        "version": VERSION,
        "media_count": media_count,
        "uptime": None,
    }


@app.get("/")
async def root():
    return {
        "name": "Cinemate Media Server",
        "version": VERSION,
        "docs": "/docs",
        "api": "/api",
    }
