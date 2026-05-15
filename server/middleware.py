"""
Security middleware for WAN mode — rate limiting, request logging, IP filtering,
brute force protection.
"""

import logging
import time
from collections import defaultdict
from datetime import datetime
from typing import Optional

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

logger = logging.getLogger("cinemate.middleware")


# ---------------------------------------------------------------------------
# Rate limiter (token bucket per IP)
# ---------------------------------------------------------------------------

class RateLimitStore:
    """In-memory token-bucket rate limiter keyed by IP."""

    def __init__(self, requests_per_minute: int = 60):
        self.rpm = requests_per_minute
        self._buckets: dict[str, dict] = {}

    def is_allowed(self, ip: str) -> bool:
        now = time.time()
        bucket = self._buckets.get(ip)
        if bucket is None:
            self._buckets[ip] = {"tokens": self.rpm - 1, "last": now}
            return True

        elapsed = now - bucket["last"]
        bucket["last"] = now
        # Refill tokens
        bucket["tokens"] = min(
            self.rpm, bucket["tokens"] + elapsed * (self.rpm / 60.0)
        )

        if bucket["tokens"] >= 1:
            bucket["tokens"] -= 1
            return True
        return False


# ---------------------------------------------------------------------------
# IP allowlist / blocklist
# ---------------------------------------------------------------------------

class IPFilter:
    """Manage IP allow/block lists. Empty allowlist means all IPs allowed."""

    def __init__(self):
        self.allowlist: set[str] = set()
        self.blocklist: set[str] = set()

    def is_allowed(self, ip: str) -> bool:
        if ip in self.blocklist:
            return False
        if self.allowlist and ip not in self.allowlist:
            return False
        return True


# ---------------------------------------------------------------------------
# Brute force tracker
# ---------------------------------------------------------------------------

class BruteForceTracker:
    """Track repeated failed requests (4xx) from an IP and temporarily block."""

    def __init__(self, max_failures: int = 20, window_seconds: int = 60, block_seconds: int = 300):
        self.max_failures = max_failures
        self.window = window_seconds
        self.block_seconds = block_seconds
        self._failures: dict[str, list[float]] = defaultdict(list)
        self._blocked: dict[str, float] = {}

    def is_blocked(self, ip: str) -> bool:
        block_until = self._blocked.get(ip)
        if block_until and time.time() < block_until:
            return True
        elif block_until:
            del self._blocked[ip]
        return False

    def record_failure(self, ip: str):
        now = time.time()
        self._failures[ip] = [
            t for t in self._failures[ip] if now - t < self.window
        ]
        self._failures[ip].append(now)
        if len(self._failures[ip]) >= self.max_failures:
            self._blocked[ip] = now + self.block_seconds
            self._failures[ip] = []
            logger.warning(f"IP {ip} blocked for {self.block_seconds}s (brute force)")


# ---------------------------------------------------------------------------
# Request logger
# ---------------------------------------------------------------------------

class RequestLogger:
    """Log requests to the database asynchronously."""

    def __init__(self, enabled: bool = True, max_batch: int = 50):
        self.enabled = enabled
        self._batch: list[tuple] = []
        self._max_batch = max_batch

    async def log(self, ip: str, endpoint: str, method: str, status_code: int):
        if not self.enabled:
            return
        now = datetime.utcnow().isoformat()
        self._batch.append((ip, endpoint, method, now, status_code))
        if len(self._batch) >= self._max_batch:
            await self.flush()

    async def flush(self):
        if not self._batch:
            return
        batch = self._batch[:]
        self._batch = []
        try:
            from database import get_db
            db = await get_db()
            try:
                await db.executemany(
                    "INSERT INTO request_log (ip, endpoint, method, timestamp, status_code) "
                    "VALUES (?, ?, ?, ?, ?)",
                    batch,
                )
                await db.commit()
            finally:
                await db.close()
        except Exception as e:
            logger.debug(f"Request log flush failed: {e}")


# ---------------------------------------------------------------------------
# The middleware
# ---------------------------------------------------------------------------

# Module-level instances so they can be configured from outside
rate_limiter = RateLimitStore(requests_per_minute=120)
ip_filter = IPFilter()
brute_force = BruteForceTracker()
request_logger = RequestLogger(enabled=True)


class WANSecurityMiddleware(BaseHTTPMiddleware):
    """
    Security middleware for WAN-exposed endpoints.

    - Rate limiting (per IP)
    - IP allowlist/blocklist
    - Brute force protection
    - Request logging
    """

    async def dispatch(self, request: Request, call_next) -> Response:
        client_ip = request.client.host if request.client else "0.0.0.0"
        path = request.url.path
        method = request.method

        # 1. IP filter
        if not ip_filter.is_allowed(client_ip):
            logger.info(f"Blocked IP: {client_ip} -> {method} {path}")
            return JSONResponse(
                status_code=403,
                content={"detail": "Access denied"},
            )

        # 2. Brute force check
        if brute_force.is_blocked(client_ip):
            return JSONResponse(
                status_code=429,
                content={"detail": "Temporarily blocked due to repeated failures"},
            )

        # 3. Rate limiting
        if not rate_limiter.is_allowed(client_ip):
            await request_logger.log(client_ip, path, method, 429)
            return JSONResponse(
                status_code=429,
                content={"detail": "Rate limit exceeded"},
            )

        # 4. Process request
        response = await call_next(request)

        # 5. Track failures for brute force detection
        if response.status_code in (401, 403):
            brute_force.record_failure(client_ip)

        # 6. Log request
        await request_logger.log(client_ip, path, method, response.status_code)

        return response
