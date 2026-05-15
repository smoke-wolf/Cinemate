"""Cinemate database layer — async SQLite via aiosqlite."""

import aiosqlite
import os
import json
from pathlib import Path
from datetime import datetime

DB_DIR = Path.home() / ".cinemate"
DB_PATH = DB_DIR / "cinemate.db"
THUMBNAIL_DIR = DB_DIR / "thumbnails"
ALBUM_ART_DIR = DB_DIR / "album_art"
BOOK_COVER_DIR = DB_DIR / "book_covers"
CONFIG_PATH = DB_DIR / "config.json"

DEFAULT_CONFIG = {
    "server_name": "Cinemate Server",
    "port": 9876,
    "allowed_ips": [],
    "require_pin": False,
    "access_mode": "lan",  # "lan", "specific_ips"
}

SCHEMA = """
CREATE TABLE IF NOT EXISTS media (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    year INTEGER,
    file_path TEXT NOT NULL UNIQUE,
    file_size INTEGER DEFAULT 0,
    format TEXT,
    genre TEXT,
    rating REAL,
    quality TEXT,
    description TEXT,
    thumbnail_path TEXT,
    media_type TEXT DEFAULT 'movie',
    show_name TEXT,
    season_number INTEGER,
    episode_number INTEGER,
    date_added TEXT DEFAULT (datetime('now')),
    duration REAL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    avatar_color TEXT DEFAULT '#6366f1',
    pin_hash TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS account_media (
    account_id INTEGER NOT NULL,
    media_id INTEGER NOT NULL,
    favorite INTEGER DEFAULT 0,
    watched INTEGER DEFAULT 0,
    watch_progress REAL DEFAULT 0,
    play_count INTEGER DEFAULT 0,
    last_played TEXT,
    total_watch_time REAL DEFAULT 0,
    rating INTEGER,
    PRIMARY KEY (account_id, media_id),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (media_id) REFERENCES media(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS comments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    media_id INTEGER NOT NULL,
    timestamp REAL,
    text TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (media_id) REFERENCES media(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS server_settings (
    key TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    account_id INTEGER,
    client_ip TEXT,
    client_name TEXT,
    connected_at TEXT DEFAULT (datetime('now')),
    last_activity TEXT DEFAULT (datetime('now')),
    currently_watching INTEGER,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE SET NULL,
    FOREIGN KEY (currently_watching) REFERENCES media(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS admin_accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    password_hash TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS admin_sessions (
    id TEXT PRIMARY KEY,
    admin_id INTEGER NOT NULL,
    token_hash TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    expires_at TEXT NOT NULL,
    revoked INTEGER DEFAULT 0,
    FOREIGN KEY (admin_id) REFERENCES admin_accounts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS wan_config (
    key TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE IF NOT EXISTS request_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip TEXT,
    endpoint TEXT,
    method TEXT,
    timestamp TEXT,
    status_code INTEGER
);

CREATE INDEX IF NOT EXISTS idx_media_title ON media(title);
CREATE INDEX IF NOT EXISTS idx_media_type ON media(media_type);
CREATE INDEX IF NOT EXISTS idx_media_genre ON media(genre);
CREATE INDEX IF NOT EXISTS idx_media_show ON media(show_name);
CREATE INDEX IF NOT EXISTS idx_account_media_account ON account_media(account_id);
CREATE INDEX IF NOT EXISTS idx_account_media_media ON account_media(media_id);
CREATE INDEX IF NOT EXISTS idx_comments_media ON comments(media_id);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_token ON admin_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_admin ON admin_sessions(admin_id);
CREATE INDEX IF NOT EXISTS idx_request_log_ip ON request_log(ip);
CREATE INDEX IF NOT EXISTS idx_request_log_timestamp ON request_log(timestamp);

-- Music library tables
CREATE TABLE IF NOT EXISTS music_tracks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    artist TEXT DEFAULT 'Unknown Artist',
    album TEXT DEFAULT 'Unknown Album',
    album_artist TEXT,
    track_number INTEGER,
    disc_number INTEGER,
    year INTEGER,
    genre TEXT,
    duration REAL DEFAULT 0,
    bitrate INTEGER,
    sample_rate INTEGER,
    format TEXT,
    file_path TEXT NOT NULL UNIQUE,
    file_size INTEGER DEFAULT 0,
    album_art_path TEXT,
    album_id INTEGER,
    date_added TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (album_id) REFERENCES music_albums(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS music_albums (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    artist TEXT DEFAULT 'Unknown Artist',
    album_artist TEXT,
    year INTEGER,
    genre TEXT,
    track_count INTEGER DEFAULT 0,
    total_duration REAL DEFAULT 0,
    art_path TEXT,
    date_added TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS playlists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS playlist_tracks (
    playlist_id INTEGER NOT NULL,
    track_id INTEGER NOT NULL,
    position INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (playlist_id, track_id),
    FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
    FOREIGN KEY (track_id) REFERENCES music_tracks(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS music_account_data (
    account_id INTEGER NOT NULL,
    track_id INTEGER NOT NULL,
    favorite INTEGER DEFAULT 0,
    play_count INTEGER DEFAULT 0,
    last_played TEXT,
    total_listen_time REAL DEFAULT 0,
    PRIMARY KEY (account_id, track_id),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (track_id) REFERENCES music_tracks(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS music_play_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    track_id INTEGER NOT NULL,
    played_at TEXT DEFAULT (datetime('now')),
    duration_listened REAL DEFAULT 0,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (track_id) REFERENCES music_tracks(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_music_tracks_artist ON music_tracks(artist);
CREATE INDEX IF NOT EXISTS idx_music_tracks_album ON music_tracks(album);
CREATE INDEX IF NOT EXISTS idx_music_tracks_album_id ON music_tracks(album_id);
CREATE INDEX IF NOT EXISTS idx_music_tracks_genre ON music_tracks(genre);
CREATE INDEX IF NOT EXISTS idx_music_tracks_file_path ON music_tracks(file_path);
CREATE INDEX IF NOT EXISTS idx_music_albums_artist ON music_albums(artist);
CREATE INDEX IF NOT EXISTS idx_playlists_account ON playlists(account_id);
CREATE INDEX IF NOT EXISTS idx_playlist_tracks_playlist ON playlist_tracks(playlist_id);
CREATE INDEX IF NOT EXISTS idx_music_account_data_account ON music_account_data(account_id);
CREATE INDEX IF NOT EXISTS idx_music_play_history_account ON music_play_history(account_id);
CREATE INDEX IF NOT EXISTS idx_music_play_history_played ON music_play_history(played_at);

-- Book library tables
CREATE TABLE IF NOT EXISTS books (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    author TEXT,
    genre TEXT,
    publisher TEXT,
    language TEXT,
    description TEXT,
    page_count INTEGER DEFAULT 0,
    format TEXT,
    file_path TEXT NOT NULL UNIQUE,
    file_size INTEGER DEFAULT 0,
    cover_path TEXT,
    year INTEGER,
    date_added TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS book_account_data (
    account_id INTEGER NOT NULL,
    book_id INTEGER NOT NULL,
    reading_progress REAL DEFAULT 0,
    current_page INTEGER DEFAULT 0,
    favorite INTEGER DEFAULT 0,
    finished INTEGER DEFAULT 0,
    started_at TEXT,
    finished_at TEXT,
    total_reading_time REAL DEFAULT 0,
    PRIMARY KEY (account_id, book_id),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS book_bookmarks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    book_id INTEGER NOT NULL,
    page INTEGER NOT NULL,
    note TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_books_title ON books(title);
CREATE INDEX IF NOT EXISTS idx_books_author ON books(author);
CREATE INDEX IF NOT EXISTS idx_books_format ON books(format);
CREATE INDEX IF NOT EXISTS idx_books_file_path ON books(file_path);
CREATE INDEX IF NOT EXISTS idx_book_account_data_account ON book_account_data(account_id);
CREATE INDEX IF NOT EXISTS idx_book_account_data_book ON book_account_data(book_id);
CREATE INDEX IF NOT EXISTS idx_book_bookmarks_account ON book_bookmarks(account_id);
CREATE INDEX IF NOT EXISTS idx_book_bookmarks_book ON book_bookmarks(book_id);
"""


def ensure_dirs():
    """Create ~/.cinemate/, thumbnails/, album_art/, and book_covers/ if they don't exist."""
    DB_DIR.mkdir(parents=True, exist_ok=True)
    THUMBNAIL_DIR.mkdir(parents=True, exist_ok=True)
    ALBUM_ART_DIR.mkdir(parents=True, exist_ok=True)
    BOOK_COVER_DIR.mkdir(parents=True, exist_ok=True)


def load_config() -> dict:
    """Load config from disk, creating defaults if missing."""
    ensure_dirs()
    if CONFIG_PATH.exists():
        with open(CONFIG_PATH) as f:
            cfg = json.load(f)
        # Merge with defaults for any missing keys
        for k, v in DEFAULT_CONFIG.items():
            cfg.setdefault(k, v)
        return cfg
    else:
        save_config(DEFAULT_CONFIG)
        return dict(DEFAULT_CONFIG)


def save_config(cfg: dict):
    """Persist config to disk."""
    ensure_dirs()
    with open(CONFIG_PATH, "w") as f:
        json.dump(cfg, f, indent=2)


async def get_db() -> aiosqlite.Connection:
    """Get an async database connection."""
    ensure_dirs()
    db = await aiosqlite.connect(str(DB_PATH))
    db.row_factory = aiosqlite.Row
    await db.execute("PRAGMA journal_mode=WAL")
    await db.execute("PRAGMA foreign_keys=ON")
    return db


async def init_db():
    """Initialize the database schema."""
    ensure_dirs()
    db = await get_db()
    try:
        await db.executescript(SCHEMA)
        await db.commit()
    finally:
        await db.close()
