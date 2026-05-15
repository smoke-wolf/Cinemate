"""
Admin authentication for WAN access — bcrypt passwords, JWT tokens, session management.
"""

import hashlib
import logging
import os
import secrets
import time
import uuid
from datetime import datetime, timedelta
from typing import Optional

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

logger = logging.getLogger("cinemate.auth")

# ---------------------------------------------------------------------------
# JWT — use python-jose if available, otherwise fall back to a simple HMAC
# ---------------------------------------------------------------------------
_JWT_SECRET: Optional[str] = None
_JWT_ALGORITHM = "HS256"
_JWT_EXPIRE_HOURS = 24

try:
    from jose import JWTError, jwt as jose_jwt

    def _create_jwt(data: dict, expires_delta: timedelta) -> str:
        payload = data.copy()
        payload["exp"] = datetime.utcnow() + expires_delta
        payload["iat"] = datetime.utcnow()
        return jose_jwt.encode(payload, _get_secret(), algorithm=_JWT_ALGORITHM)

    def _decode_jwt(token: str) -> dict:
        return jose_jwt.decode(token, _get_secret(), algorithms=[_JWT_ALGORITHM])

except ImportError:
    # Minimal fallback using hmac — enough for a local media server
    import hmac, json, base64

    def _b64e(data: bytes) -> str:
        return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

    def _b64d(s: str) -> bytes:
        s += "=" * (-len(s) % 4)
        return base64.urlsafe_b64decode(s)

    class JWTError(Exception):
        pass

    def _create_jwt(data: dict, expires_delta: timedelta) -> str:
        import json as _json
        payload = data.copy()
        payload["exp"] = (datetime.utcnow() + expires_delta).timestamp()
        payload["iat"] = datetime.utcnow().timestamp()
        header = _b64e(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
        body = _b64e(json.dumps(payload).encode())
        sig = hmac.new(_get_secret().encode(), f"{header}.{body}".encode(), "sha256").digest()
        return f"{header}.{body}.{_b64e(sig)}"

    def _decode_jwt(token: str) -> dict:
        import json as _json
        parts = token.split(".")
        if len(parts) != 3:
            raise JWTError("Invalid token format")
        header, body, sig = parts
        expected_sig = hmac.new(
            _get_secret().encode(), f"{header}.{body}".encode(), "sha256"
        ).digest()
        if not hmac.compare_digest(_b64d(sig), expected_sig):
            raise JWTError("Invalid signature")
        payload = json.loads(_b64d(body))
        if payload.get("exp", 0) < datetime.utcnow().timestamp():
            raise JWTError("Token expired")
        return payload


# ---------------------------------------------------------------------------
# Password hashing — use passlib/bcrypt if available, fallback to pbkdf2
# ---------------------------------------------------------------------------
try:
    from passlib.context import CryptContext

    _pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")

    def hash_password(password: str) -> str:
        return _pwd_ctx.hash(password)

    def verify_password(password: str, hashed: str) -> bool:
        return _pwd_ctx.verify(password, hashed)

except ImportError:
    import hashlib as _hl

    logger.warning("passlib not installed — using PBKDF2 fallback for password hashing")

    def hash_password(password: str) -> str:
        salt = secrets.token_hex(16)
        dk = _hl.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 200_000)
        return f"pbkdf2:{salt}:{dk.hex()}"

    def verify_password(password: str, hashed: str) -> bool:
        parts = hashed.split(":")
        if len(parts) != 3 or parts[0] != "pbkdf2":
            return False
        salt = parts[1]
        dk = _hl.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 200_000)
        return secrets.compare_digest(dk.hex(), parts[2])


# ---------------------------------------------------------------------------
# Secret key management
# ---------------------------------------------------------------------------

def _get_secret() -> str:
    """Return (or create) the JWT signing secret."""
    global _JWT_SECRET
    if _JWT_SECRET:
        return _JWT_SECRET

    from database import DB_DIR

    secret_path = DB_DIR / ".jwt_secret"
    if secret_path.exists():
        _JWT_SECRET = secret_path.read_text().strip()
    else:
        _JWT_SECRET = secrets.token_hex(32)
        DB_DIR.mkdir(parents=True, exist_ok=True)
        secret_path.write_text(_JWT_SECRET)
        # Restrict permissions
        os.chmod(str(secret_path), 0o600)
    return _JWT_SECRET


# ---------------------------------------------------------------------------
# Rate limiting for login attempts
# ---------------------------------------------------------------------------

class LoginRateLimiter:
    """Track failed login attempts per IP. 5 attempts/minute then lockout."""

    def __init__(self, max_attempts: int = 5, window_seconds: int = 60):
        self.max_attempts = max_attempts
        self.window = window_seconds
        self._attempts: dict[str, list[float]] = {}  # ip -> [timestamps]

    def check(self, ip: str) -> bool:
        """Return True if the IP is allowed to attempt login."""
        now = time.time()
        attempts = self._attempts.get(ip, [])
        # Prune old attempts outside the window
        attempts = [t for t in attempts if now - t < self.window]
        self._attempts[ip] = attempts
        return len(attempts) < self.max_attempts

    def record_attempt(self, ip: str):
        """Record a failed login attempt."""
        now = time.time()
        if ip not in self._attempts:
            self._attempts[ip] = []
        self._attempts[ip].append(now)

    def remaining(self, ip: str) -> int:
        """How many attempts left for this IP."""
        now = time.time()
        attempts = [t for t in self._attempts.get(ip, []) if now - t < self.window]
        return max(0, self.max_attempts - len(attempts))

    def reset(self, ip: str):
        """Clear attempts for an IP (on successful login)."""
        self._attempts.pop(ip, None)


login_limiter = LoginRateLimiter()


# ---------------------------------------------------------------------------
# Admin CRUD (uses the wan DB tables)
# ---------------------------------------------------------------------------

async def admin_exists() -> bool:
    """Check if an admin account has been set up."""
    from database import get_db
    db = await get_db()
    try:
        cursor = await db.execute("SELECT COUNT(*) as cnt FROM admin_accounts")
        row = await cursor.fetchone()
        return row["cnt"] > 0
    finally:
        await db.close()


async def create_admin(password: str) -> dict:
    """Create the admin account. Only works once (single admin)."""
    if await admin_exists():
        raise ValueError("Admin account already exists")

    from database import get_db
    pw_hash = hash_password(password)
    db = await get_db()
    try:
        cursor = await db.execute(
            "INSERT INTO admin_accounts (password_hash) VALUES (?)",
            (pw_hash,),
        )
        await db.commit()
        admin_id = cursor.lastrowid
        logger.info(f"Admin account created (id={admin_id})")
        return {"id": admin_id, "created": True}
    finally:
        await db.close()


async def verify_admin(password: str) -> Optional[dict]:
    """Verify admin password. Returns admin row dict or None."""
    from database import get_db
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id, password_hash, created_at FROM admin_accounts LIMIT 1"
        )
        row = await cursor.fetchone()
        if not row:
            return None
        if verify_password(password, row["password_hash"]):
            return {"id": row["id"], "created_at": row["created_at"]}
        return None
    finally:
        await db.close()


async def change_admin_password(admin_id: int, new_password: str):
    """Update the admin password."""
    from database import get_db
    pw_hash = hash_password(new_password)
    db = await get_db()
    try:
        await db.execute(
            "UPDATE admin_accounts SET password_hash = ? WHERE id = ?",
            (pw_hash, admin_id),
        )
        await db.commit()
    finally:
        await db.close()


# ---------------------------------------------------------------------------
# Session management
# ---------------------------------------------------------------------------

async def create_session(admin_id: int) -> dict:
    """Create a new admin session, return session dict with token."""
    from database import get_db

    session_id = str(uuid.uuid4())
    expires = datetime.utcnow() + timedelta(hours=_JWT_EXPIRE_HOURS)

    token = _create_jwt(
        {"sub": str(admin_id), "sid": session_id},
        timedelta(hours=_JWT_EXPIRE_HOURS),
    )
    token_hash = hashlib.sha256(token.encode()).hexdigest()

    db = await get_db()
    try:
        await db.execute(
            "INSERT INTO admin_sessions (id, admin_id, token_hash, expires_at) VALUES (?, ?, ?, ?)",
            (session_id, admin_id, token_hash, expires.isoformat()),
        )
        await db.commit()
    finally:
        await db.close()

    return {
        "session_id": session_id,
        "token": token,
        "expires_at": expires.isoformat(),
    }


async def validate_session(token: str) -> dict:
    """Validate a JWT and its corresponding session. Returns payload or raises."""
    try:
        payload = _decode_jwt(token)
    except (JWTError, Exception) as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {e}",
        )

    session_id = payload.get("sid")
    if not session_id:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    from database import get_db
    token_hash = hashlib.sha256(token.encode()).hexdigest()

    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM admin_sessions WHERE id = ? AND token_hash = ? AND revoked = 0",
            (session_id, token_hash),
        )
        session = await cursor.fetchone()
        if not session:
            raise HTTPException(status_code=401, detail="Session not found or revoked")

        if session["expires_at"] < datetime.utcnow().isoformat():
            raise HTTPException(status_code=401, detail="Session expired")

    finally:
        await db.close()

    return payload


async def list_sessions() -> list[dict]:
    """List all active (non-revoked, non-expired) admin sessions."""
    from database import get_db
    db = await get_db()
    try:
        now = datetime.utcnow().isoformat()
        cursor = await db.execute(
            "SELECT id, admin_id, created_at, expires_at FROM admin_sessions "
            "WHERE revoked = 0 AND expires_at > ? ORDER BY created_at DESC",
            (now,),
        )
        rows = await cursor.fetchall()
        return [dict(r) for r in rows]
    finally:
        await db.close()


async def revoke_session(session_id: str) -> bool:
    """Revoke a session by ID. Returns True if found."""
    from database import get_db
    db = await get_db()
    try:
        cursor = await db.execute(
            "UPDATE admin_sessions SET revoked = 1 WHERE id = ?",
            (session_id,),
        )
        await db.commit()
        return cursor.rowcount > 0
    finally:
        await db.close()


# ---------------------------------------------------------------------------
# FastAPI dependency — require_admin
# ---------------------------------------------------------------------------

_bearer_scheme = HTTPBearer(auto_error=False)


async def require_admin(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer_scheme),
) -> dict:
    """
    FastAPI dependency: extracts and validates the admin JWT.
    Returns the decoded token payload on success; raises 401 otherwise.
    """
    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return await validate_session(credentials.credentials)
