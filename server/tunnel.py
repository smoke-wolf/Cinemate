"""
Tunnel manager for WAN access — supports ngrok, cloudflared, and custom domains.

Usage is opt-in: the server works fine without ngrok or cloudflared installed.
"""

import asyncio
import logging
import re
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional

logger = logging.getLogger("cinemate.tunnel")


class TunnelType(str, Enum):
    NGROK = "ngrok"
    CLOUDFLARED = "cloudflared"
    CUSTOM = "custom"


class TunnelState(str, Enum):
    DISCONNECTED = "disconnected"
    CONNECTING = "connecting"
    CONNECTED = "connected"
    RECONNECTING = "reconnecting"
    ERROR = "error"


@dataclass
class TunnelStatus:
    tunnel_type: Optional[str] = None
    state: str = TunnelState.DISCONNECTED
    public_url: Optional[str] = None
    started_at: Optional[float] = None
    error: Optional[str] = None
    reconnect_count: int = 0

    @property
    def uptime_seconds(self) -> float:
        if self.started_at and self.state == TunnelState.CONNECTED:
            return time.time() - self.started_at
        return 0.0

    def to_dict(self) -> dict:
        return {
            "tunnel_type": self.tunnel_type,
            "state": self.state,
            "public_url": self.public_url,
            "uptime_seconds": round(self.uptime_seconds, 1),
            "started_at": self.started_at,
            "error": self.error,
            "reconnect_count": self.reconnect_count,
        }


class TunnelManager:
    """Manages a single tunnel process (ngrok, cloudflared, or custom domain)."""

    def __init__(self):
        self._process: Optional[asyncio.subprocess.Process] = None
        self._status = TunnelStatus()
        self._monitor_task: Optional[asyncio.Task] = None
        self._config: dict = {}
        self._stop_requested = False
        self._max_reconnects = 10
        self._reconnect_delay = 5  # seconds

    @property
    def status(self) -> TunnelStatus:
        return self._status

    def get_public_url(self) -> Optional[str]:
        return self._status.public_url

    async def start(self, tunnel_type: str, config: Optional[dict] = None) -> dict:
        """
        Start a tunnel.

        Args:
            tunnel_type: "ngrok", "cloudflared", or "custom"
            config: Type-specific config:
                ngrok: {"port": 9876, "authtoken": "...", "region": "us"}
                cloudflared: {"port": 9876}
                custom: {"url": "https://my.domain.com", "ssl_cert": "...", "ssl_key": "..."}

        Returns:
            Status dict.
        """
        if self._status.state in (TunnelState.CONNECTED, TunnelState.CONNECTING):
            await self.stop()

        self._config = config or {}
        self._stop_requested = False
        self._status = TunnelStatus(tunnel_type=tunnel_type, state=TunnelState.CONNECTING)

        try:
            if tunnel_type == TunnelType.NGROK:
                await self._start_ngrok()
            elif tunnel_type == TunnelType.CLOUDFLARED:
                await self._start_cloudflared()
            elif tunnel_type == TunnelType.CUSTOM:
                self._start_custom()
            else:
                raise ValueError(f"Unknown tunnel type: {tunnel_type}")
        except Exception as e:
            self._status.state = TunnelState.ERROR
            self._status.error = str(e)
            logger.error(f"Tunnel start failed: {e}")
            return self._status.to_dict()

        return self._status.to_dict()

    async def stop(self) -> dict:
        """Stop the active tunnel and clean up."""
        self._stop_requested = True

        if self._monitor_task and not self._monitor_task.done():
            self._monitor_task.cancel()
            try:
                await self._monitor_task
            except asyncio.CancelledError:
                pass
            self._monitor_task = None

        if self._process:
            try:
                self._process.terminate()
                try:
                    await asyncio.wait_for(self._process.wait(), timeout=5.0)
                except asyncio.TimeoutError:
                    self._process.kill()
                    await self._process.wait()
            except ProcessLookupError:
                pass
            self._process = None

        self._status = TunnelStatus(
            tunnel_type=self._status.tunnel_type,
            state=TunnelState.DISCONNECTED,
        )
        logger.info("Tunnel stopped")
        return self._status.to_dict()

    # ------------------------------------------------------------------
    # ngrok
    # ------------------------------------------------------------------

    async def _start_ngrok(self):
        """Start ngrok tunnel via subprocess."""
        port = self._config.get("port", 9876)
        authtoken = self._config.get("authtoken")
        region = self._config.get("region", "us")

        cmd = ["ngrok", "http", str(port), "--region", region, "--log", "stdout"]
        if authtoken:
            cmd.extend(["--authtoken", authtoken])

        try:
            self._process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
        except FileNotFoundError:
            raise RuntimeError(
                "ngrok not found. Install it: https://ngrok.com/download"
            )

        # Wait for ngrok to come up, then poll its local API for the public URL
        await asyncio.sleep(2)
        url = await self._poll_ngrok_api()
        if url:
            self._status.state = TunnelState.CONNECTED
            self._status.public_url = url
            self._status.started_at = time.time()
            logger.info(f"ngrok tunnel connected: {url}")
        else:
            self._status.state = TunnelState.ERROR
            self._status.error = "Could not retrieve ngrok public URL"
            await self.stop()
            return

        # Start health monitor
        self._monitor_task = asyncio.create_task(self._monitor_ngrok())

    async def _poll_ngrok_api(self, retries: int = 5) -> Optional[str]:
        """Fetch the public URL from ngrok's local API."""
        import urllib.request
        import json as _json

        api_url = self._config.get("api_url", "http://localhost:4040/api/tunnels")
        for attempt in range(retries):
            try:
                resp = await asyncio.to_thread(
                    lambda: urllib.request.urlopen(api_url, timeout=3).read()
                )
                data = _json.loads(resp)
                tunnels = data.get("tunnels", [])
                for t in tunnels:
                    pub = t.get("public_url", "")
                    if pub.startswith("https://"):
                        return pub
                # Fall back to any URL
                if tunnels:
                    return tunnels[0].get("public_url")
            except Exception:
                await asyncio.sleep(1)
        return None

    async def _monitor_ngrok(self):
        """Watch the ngrok process; reconnect if it dies."""
        try:
            while not self._stop_requested:
                if self._process is None:
                    break
                retcode = self._process.returncode
                if retcode is not None:
                    # Process exited
                    if self._stop_requested:
                        break
                    logger.warning(f"ngrok exited with code {retcode}")
                    if self._status.reconnect_count < self._max_reconnects:
                        self._status.state = TunnelState.RECONNECTING
                        self._status.reconnect_count += 1
                        await asyncio.sleep(self._reconnect_delay)
                        if not self._stop_requested:
                            await self._start_ngrok()
                    else:
                        self._status.state = TunnelState.ERROR
                        self._status.error = "Max reconnect attempts exceeded"
                    break
                # Also verify the URL is still valid periodically
                await asyncio.sleep(10)
                url = await self._poll_ngrok_api(retries=1)
                if url and url != self._status.public_url:
                    self._status.public_url = url
                    logger.info(f"ngrok URL updated: {url}")
        except asyncio.CancelledError:
            pass

    # ------------------------------------------------------------------
    # cloudflared
    # ------------------------------------------------------------------

    async def _start_cloudflared(self):
        """Start cloudflared quick tunnel."""
        port = self._config.get("port", 9876)
        cmd = ["cloudflared", "tunnel", "--url", f"http://localhost:{port}"]

        try:
            self._process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
        except FileNotFoundError:
            raise RuntimeError(
                "cloudflared not found. Install it: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
            )

        # cloudflared prints the URL to stderr
        url = await self._parse_cloudflared_url()
        if url:
            self._status.state = TunnelState.CONNECTED
            self._status.public_url = url
            self._status.started_at = time.time()
            logger.info(f"cloudflared tunnel connected: {url}")
        else:
            self._status.state = TunnelState.ERROR
            self._status.error = "Could not parse cloudflared URL from output"
            await self.stop()
            return

        self._monitor_task = asyncio.create_task(self._monitor_cloudflared())

    async def _parse_cloudflared_url(self, timeout: float = 30.0) -> Optional[str]:
        """Read cloudflared stderr until we find the generated URL."""
        if not self._process or not self._process.stderr:
            return None

        url_pattern = re.compile(r"(https://[a-zA-Z0-9\-]+\.trycloudflare\.com)")
        deadline = time.time() + timeout

        while time.time() < deadline:
            try:
                line = await asyncio.wait_for(
                    self._process.stderr.readline(), timeout=2.0
                )
                if not line:
                    if self._process.returncode is not None:
                        break
                    continue
                text = line.decode("utf-8", errors="replace").strip()
                logger.debug(f"cloudflared: {text}")
                match = url_pattern.search(text)
                if match:
                    return match.group(1)
            except asyncio.TimeoutError:
                continue
        return None

    async def _monitor_cloudflared(self):
        """Watch the cloudflared process; reconnect if it dies."""
        try:
            while not self._stop_requested:
                if self._process is None:
                    break
                retcode = self._process.returncode
                if retcode is not None:
                    if self._stop_requested:
                        break
                    logger.warning(f"cloudflared exited with code {retcode}")
                    if self._status.reconnect_count < self._max_reconnects:
                        self._status.state = TunnelState.RECONNECTING
                        self._status.reconnect_count += 1
                        await asyncio.sleep(self._reconnect_delay)
                        if not self._stop_requested:
                            await self._start_cloudflared()
                    else:
                        self._status.state = TunnelState.ERROR
                        self._status.error = "Max reconnect attempts exceeded"
                    break
                await asyncio.sleep(10)
        except asyncio.CancelledError:
            pass

    # ------------------------------------------------------------------
    # Custom domain
    # ------------------------------------------------------------------

    def _start_custom(self):
        """Store a custom domain URL (no subprocess needed)."""
        url = self._config.get("url")
        if not url:
            raise ValueError("Custom domain requires 'url' in config")
        self._status.state = TunnelState.CONNECTED
        self._status.public_url = url
        self._status.started_at = time.time()
        logger.info(f"Custom domain configured: {url}")


# Singleton instance
tunnel_manager = TunnelManager()
