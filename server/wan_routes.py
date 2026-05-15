"""
WAN API routes — tunnel management, admin auth, domain configuration.

All config endpoints require admin auth (except login and initial setup).
"""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from auth import (
    admin_exists,
    change_admin_password,
    create_admin,
    create_session,
    list_sessions,
    login_limiter,
    require_admin,
    revoke_session,
    verify_admin,
)
from tunnel import TunnelType, tunnel_manager

logger = logging.getLogger("cinemate.wan")

router = APIRouter(prefix="/api/wan", tags=["WAN"])


# ---------------------------------------------------------------------------
# Request / response models
# ---------------------------------------------------------------------------

class TunnelStartRequest(BaseModel):
    type: str  # "ngrok", "cloudflared", "custom"
    config: dict = {}


class AdminLoginRequest(BaseModel):
    password: str


class AdminSetupRequest(BaseModel):
    password: str


class AdminPasswordChange(BaseModel):
    new_password: str


class DomainConfig(BaseModel):
    url: str
    ssl_cert_path: Optional[str] = None
    ssl_key_path: Optional[str] = None


class WanConfigUpdate(BaseModel):
    wan_enabled: Optional[bool] = None
    tunnel_type: Optional[str] = None
    auto_start_tunnel: Optional[bool] = None
    require_auth_for_media: Optional[bool] = None


# ---------------------------------------------------------------------------
# Tunnel endpoints
# ---------------------------------------------------------------------------

@router.post("/tunnel/start")
async def start_tunnel(req: TunnelStartRequest, _admin: dict = Depends(require_admin)):
    """Start a tunnel (ngrok, cloudflared, or custom domain)."""
    if req.type not in ("ngrok", "cloudflared", "custom"):
        raise HTTPException(400, f"Invalid tunnel type: {req.type}")

    result = await tunnel_manager.start(req.type, req.config)

    # Persist choice to wan_config
    from database import get_db
    db = await get_db()
    try:
        await db.execute(
            "INSERT OR REPLACE INTO wan_config (key, value) VALUES (?, ?)",
            ("tunnel_type", req.type),
        )
        await db.commit()
    finally:
        await db.close()

    return result


@router.post("/tunnel/stop")
async def stop_tunnel(_admin: dict = Depends(require_admin)):
    """Stop the active tunnel."""
    return await tunnel_manager.stop()


@router.get("/tunnel/status")
async def tunnel_status():
    """Get current tunnel status and public URL. No auth required (read-only)."""
    return tunnel_manager.status.to_dict()


# ---------------------------------------------------------------------------
# WAN config
# ---------------------------------------------------------------------------

@router.get("/config")
async def get_wan_config(_admin: dict = Depends(require_admin)):
    """Get all WAN configuration values."""
    from database import get_db
    db = await get_db()
    try:
        cursor = await db.execute("SELECT key, value FROM wan_config")
        rows = await cursor.fetchall()
        config = {row["key"]: row["value"] for row in rows}
        # Include live tunnel status
        config["tunnel_status"] = tunnel_manager.status.to_dict()
        return config
    finally:
        await db.close()


@router.put("/config")
async def update_wan_config(data: WanConfigUpdate, _admin: dict = Depends(require_admin)):
    """Update WAN configuration."""
    from database import get_db
    db = await get_db()
    try:
        updates = data.model_dump(exclude_none=True)
        for key, value in updates.items():
            await db.execute(
                "INSERT OR REPLACE INTO wan_config (key, value) VALUES (?, ?)",
                (key, str(value)),
            )
        await db.commit()
        # Return updated config
        cursor = await db.execute("SELECT key, value FROM wan_config")
        rows = await cursor.fetchall()
        return {row["key"]: row["value"] for row in rows}
    finally:
        await db.close()


# ---------------------------------------------------------------------------
# Admin auth endpoints
# ---------------------------------------------------------------------------

@router.post("/admin/setup")
async def admin_setup(req: AdminSetupRequest):
    """
    Initial admin password setup. Only works once -- if an admin already
    exists, returns 409.
    """
    if await admin_exists():
        raise HTTPException(409, "Admin account already configured")

    if len(req.password) < 8:
        raise HTTPException(400, "Password must be at least 8 characters")

    result = await create_admin(req.password)
    # Auto-login after setup
    session = await create_session(result["id"])
    return {
        "message": "Admin account created",
        "admin_id": result["id"],
        "token": session["token"],
        "expires_at": session["expires_at"],
    }


@router.post("/admin/login")
async def admin_login(req: AdminLoginRequest, request: Request):
    """Authenticate as admin and receive a JWT."""
    client_ip = request.client.host if request.client else "unknown"

    if not login_limiter.check(client_ip):
        remaining = login_limiter.remaining(client_ip)
        raise HTTPException(
            429,
            detail=f"Too many login attempts. Try again later. ({remaining} attempts remaining)",
        )

    admin = await verify_admin(req.password)
    if not admin:
        login_limiter.record_attempt(client_ip)
        remaining = login_limiter.remaining(client_ip)
        raise HTTPException(
            401,
            detail=f"Invalid password ({remaining} attempts remaining)",
        )

    login_limiter.reset(client_ip)
    session = await create_session(admin["id"])
    return {
        "message": "Login successful",
        "token": session["token"],
        "session_id": session["session_id"],
        "expires_at": session["expires_at"],
    }


@router.put("/admin/password")
async def change_password(
    req: AdminPasswordChange,
    admin_payload: dict = Depends(require_admin),
):
    """Change the admin password. Requires current valid token."""
    if len(req.new_password) < 8:
        raise HTTPException(400, "Password must be at least 8 characters")

    admin_id = int(admin_payload["sub"])
    await change_admin_password(admin_id, req.new_password)
    return {"message": "Password changed successfully"}


@router.get("/admin/sessions")
async def get_sessions(_admin: dict = Depends(require_admin)):
    """List all active admin sessions."""
    sessions = await list_sessions()
    return {"sessions": sessions}


@router.delete("/admin/sessions/{session_id}")
async def delete_session(session_id: str, _admin: dict = Depends(require_admin)):
    """Revoke a specific admin session."""
    revoked = await revoke_session(session_id)
    if not revoked:
        raise HTTPException(404, "Session not found")
    return {"revoked": session_id}


# ---------------------------------------------------------------------------
# Domain config
# ---------------------------------------------------------------------------

@router.get("/domain")
async def get_domain(_admin: dict = Depends(require_admin)):
    """Get custom domain configuration."""
    from database import get_db
    db = await get_db()
    try:
        domain_keys = ("custom_domain_url", "ssl_cert_path", "ssl_key_path")
        config = {}
        for key in domain_keys:
            cursor = await db.execute(
                "SELECT value FROM wan_config WHERE key = ?", (key,)
            )
            row = await cursor.fetchone()
            config[key] = row["value"] if row else None
        return config
    finally:
        await db.close()


@router.put("/domain")
async def set_domain(data: DomainConfig, _admin: dict = Depends(require_admin)):
    """Set custom domain URL and optional SSL cert paths."""
    from database import get_db
    db = await get_db()
    try:
        await db.execute(
            "INSERT OR REPLACE INTO wan_config (key, value) VALUES (?, ?)",
            ("custom_domain_url", data.url),
        )
        if data.ssl_cert_path:
            await db.execute(
                "INSERT OR REPLACE INTO wan_config (key, value) VALUES (?, ?)",
                ("ssl_cert_path", data.ssl_cert_path),
            )
        if data.ssl_key_path:
            await db.execute(
                "INSERT OR REPLACE INTO wan_config (key, value) VALUES (?, ?)",
                ("ssl_key_path", data.ssl_key_path),
            )
        await db.commit()

        return {
            "message": "Domain configuration updated",
            "custom_domain_url": data.url,
            "ssl_cert_path": data.ssl_cert_path,
            "ssl_key_path": data.ssl_key_path,
        }
    finally:
        await db.close()
