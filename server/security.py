"""
Security helpers for Cinemate — path validation, scan directory restriction,
and file-serving guards.
"""

import logging
import os
from pathlib import Path
from typing import Optional

from fastapi import HTTPException

logger = logging.getLogger("cinemate.security")

# Directories under $HOME that must never be scanned or served
_FORBIDDEN_HOME_DIRS = {
    ".ssh", ".aws", ".gnupg", ".gpg", ".config/gcloud", ".azure",
    ".kube", ".docker", ".npmrc", ".pypirc", ".netrc",
    ".git-credentials", ".password-store",
}


def get_allowed_media_dirs() -> list[str]:
    """Return the list of configured media directories (resolved to real paths).

    Falls back to $HOME if nothing is configured, excluding sensitive dotdirs.
    """
    from database import load_config, THUMBNAIL_DIR, ALBUM_ART_DIR, ARTIST_IMG_DIR, BOOK_COVER_DIR, UPLOAD_DIR

    cfg = load_config()
    media_dirs = cfg.get("media_dirs", [])

    # Always include the Cinemate data directories (thumbnails, art, uploads)
    built_in = [
        str(THUMBNAIL_DIR),
        str(ALBUM_ART_DIR),
        str(ARTIST_IMG_DIR),
        str(BOOK_COVER_DIR),
        str(UPLOAD_DIR),
    ]
    all_dirs = list(media_dirs) + built_in

    resolved = []
    for d in all_dirs:
        rp = os.path.realpath(d)
        if os.path.isdir(rp):
            resolved.append(rp)
    return resolved


def validate_scan_path(path: str) -> str:
    """Validate that a scan path is allowed.

    Returns the resolved real path, or raises HTTPException(403).
    """
    from database import load_config

    real_path = os.path.realpath(path)

    if not os.path.isdir(real_path):
        raise HTTPException(400, "Directory not found")

    cfg = load_config()
    media_dirs = cfg.get("media_dirs", [])

    if media_dirs:
        # If media directories are configured, the scan path must be under one of them
        for mdir in media_dirs:
            resolved_mdir = os.path.realpath(mdir)
            if real_path == resolved_mdir or real_path.startswith(resolved_mdir + os.sep):
                return real_path
        raise HTTPException(
            403,
            "Scan path is not under any configured media directory",
        )

    # No media dirs configured: allow paths under user's home, excluding sensitive dirs
    home = os.path.realpath(str(Path.home()))
    if not (real_path == home or real_path.startswith(home + os.sep)):
        raise HTTPException(
            403,
            "Scan path must be under your home directory (no media directories configured)",
        )

    # Check for forbidden dotdirs
    rel = os.path.relpath(real_path, home)
    for forbidden in _FORBIDDEN_HOME_DIRS:
        if rel == forbidden or rel.startswith(forbidden + os.sep):
            raise HTTPException(403, "Access to this directory is not allowed")

    return real_path


def safe_file_path(path: str, allowed_dirs: Optional[list[str]] = None) -> str:
    """Resolve a file path and verify it falls under an allowed directory.

    When called without explicit allowed_dirs:
      - Always blocks access to sensitive directories (.ssh, .aws, .gnupg, etc.)
      - If media_dirs are configured in config, restricts to those + Cinemate data dirs
      - If no media_dirs configured, allows paths under the user's home directory
        (matching the scan path policy -- the DB stores paths from prior scans)

    Args:
        path: The file path to validate.
        allowed_dirs: Optional explicit list. If None, auto-determines from config.

    Returns:
        The resolved real path.

    Raises:
        HTTPException(403) if the path is outside allowed directories or
        points to a sensitive location.
    """
    real = os.path.realpath(path)
    home = os.path.realpath(str(Path.home()))

    # Always block access to sensitive directories regardless of config
    if real.startswith(home + os.sep):
        rel = os.path.relpath(real, home)
        for forbidden in _FORBIDDEN_HOME_DIRS:
            if rel == forbidden or rel.startswith(forbidden + os.sep):
                raise HTTPException(403, "Access denied")

    if allowed_dirs is not None:
        # Explicit allowlist: strict containment check
        for allowed in allowed_dirs:
            resolved_allowed = os.path.realpath(allowed)
            if real == resolved_allowed or real.startswith(resolved_allowed + os.sep):
                return real
        raise HTTPException(403, "Access denied")

    # Auto-determine allowed dirs from config
    from database import load_config
    cfg = load_config()
    media_dirs = cfg.get("media_dirs", [])

    # Build the allowed list: Cinemate data dirs + configured media dirs
    check_dirs = get_allowed_media_dirs()
    for d in media_dirs:
        rp = os.path.realpath(d)
        if rp not in check_dirs:
            check_dirs.append(rp)

    # If media_dirs are configured, strictly enforce containment
    if media_dirs:
        for allowed in check_dirs:
            resolved_allowed = os.path.realpath(allowed)
            if real == resolved_allowed or real.startswith(resolved_allowed + os.sep):
                return real
        raise HTTPException(403, "Access denied")

    # No media_dirs configured: allow anything under home (except forbidden dirs,
    # already checked above). This matches the scan policy: if no media_dirs are
    # set, scans are allowed under $HOME, so DB-sourced paths from those scans
    # should be servable.
    if real.startswith(home + os.sep) or real == home:
        return real

    # Also allow Cinemate data dirs (thumbnails, artwork, etc.) which may be
    # outside home on some setups
    for allowed in check_dirs:
        resolved_allowed = os.path.realpath(allowed)
        if real == resolved_allowed or real.startswith(resolved_allowed + os.sep):
            return real

    raise HTTPException(403, "Access denied")
