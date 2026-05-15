# Server Guide

The Cinemate server is a Python FastAPI application that handles media scanning, metadata extraction, streaming, and multi-account state management.

## Setup

```bash
cd server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

You'll also need **ffmpeg** installed for thumbnail generation and audio waveforms:
```bash
# macOS
brew install ffmpeg

# Ubuntu/Debian
sudo apt install ffmpeg

# Windows
winget install ffmpeg
```

## Running

```bash
python3 -m uvicorn main:app --host 0.0.0.0 --port 9876 --reload
```

The `--reload` flag is handy for development — it restarts the server when you edit code. Drop it in production.

Once running, open `http://localhost:9876/docs` for the interactive API documentation (Swagger UI).

## How it works

### LAN Discovery

The server advertises itself on your local network using Zeroconf (mDNS/DNS-SD). Client apps listen for this broadcast and connect automatically — no manual IP entry needed.

### Media Scanning

Point the scanner at a directory and it walks the tree looking for media files:

- **Movies**: `.mp4`, `.mkv`, `.avi`, `.mov`, `.wmv` — extracts title, year, quality, genre from filename patterns and embedded metadata. Generates thumbnails via ffmpeg.
- **Music**: `.mp3`, `.flac`, `.m4a`, `.aac`, `.wav`, `.ogg`, `.opus`, `.aiff`, `.wma`, `.alac` — reads ID3/Vorbis/MP4 tags via Mutagen. Extracts album art and stores it separately.
- **Books**: `.epub`, `.pdf` — extracts title, author, cover image.

Scanning runs in the background. Progress is broadcast to connected clients over WebSocket.

### Streaming

Audio and video streaming use HTTP Range requests. The client can seek to any position without downloading the entire file. The server reads the requested byte range and streams it back.

### Database

SQLite via aiosqlite. Tables:

| Table | Purpose |
|-------|---------|
| `movies` | Movie metadata and file paths |
| `tv_shows` / `tv_episodes` | Show and episode metadata |
| `music_tracks` | Track metadata (title, artist, album, duration, file path) |
| `music_albums` | Album metadata with art paths |
| `accounts` | User accounts with optional PIN |
| `playlists` / `playlist_tracks` | Per-account playlists |
| `music_play_history` | Play event log |
| `music_account_data` | Per-user favorites, play counts, listen time |
| `watch_history` | Movie/episode progress |
| `favorites` | Movie/show favorites |
| `server_settings` | Key-value config store |

### Accounts

Multiple accounts per server. Each account has its own watch history, favorites, playlists, and listening stats. Accounts can optionally have a PIN for basic access control.

### WebSocket

Clients connect to `/ws` for real-time updates. The server broadcasts events like scan progress, library changes, and playback state. This keeps all connected clients in sync.

## API Reference

### Library

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/music/tracks` | List tracks. Query params: `search`, `sort`, `order`, `artist`, `album`, `genre`, `limit`, `offset` |
| GET | `/api/music/tracks/{id}` | Single track details |
| GET | `/api/music/artists` | List artists with counts |
| GET | `/api/music/artists/{name}` | Artist detail with albums and tracks |
| GET | `/api/music/albums` | List albums. Query params: `search`, `artist`, `year`, `sort`, `order` |
| GET | `/api/music/albums/{id}` | Album detail with track listing |
| GET | `/api/music/genres` | Genre list with counts |
| GET | `/api/music/stats` | Library-wide stats (totals, format breakdown) |
| POST | `/api/music/scan` | Start a background music scan. Body: `{"path": "/your/music"}` |
| GET | `/api/music/scan/status` | Current scan progress |

### Streaming

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/music/stream/{id}` | Stream audio (supports Range headers) |
| GET | `/api/music/art/{album_id}` | Serve album artwork |
| GET | `/api/music/waveform/{id}` | Generate waveform data (array of 0.0-1.0 amplitudes) |

### Per-Account

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/accounts/{id}/playlists` | List playlists |
| POST | `/api/accounts/{id}/playlists` | Create playlist |
| PUT | `/api/accounts/{id}/playlists/{pid}` | Update playlist |
| DELETE | `/api/accounts/{id}/playlists/{pid}` | Delete playlist |
| POST | `/api/accounts/{id}/playlists/{pid}/tracks` | Add tracks to playlist |
| DELETE | `/api/accounts/{id}/playlists/{pid}/tracks/{tid}` | Remove track from playlist |
| GET | `/api/accounts/{id}/music/recently-played` | Recent listening history |
| GET | `/api/accounts/{id}/music/favorites` | Favorited tracks |
| POST | `/api/accounts/{id}/music/favorites/{tid}` | Toggle favorite |
| GET | `/api/accounts/{id}/music/stats` | Listening stats (top artists, genres, play counts) |
| GET | `/api/accounts/{id}/music/queue` | Get playback queue |
| PUT | `/api/accounts/{id}/music/queue` | Set playback queue |
| POST | `/api/accounts/{id}/music/history` | Log a play event |

### Movies & TV

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/movies` | List all movies |
| GET | `/api/movies/{id}` | Movie details |
| POST | `/api/scan` | Scan directory for movies |
| GET | `/api/tv-shows` | List TV shows |
| GET | `/api/tv-shows/{id}` | Show details with seasons/episodes |
| GET | `/api/accounts/{id}/history` | Watch history |
| POST | `/api/accounts/{id}/history` | Update progress |
| GET | `/api/accounts/{id}/favorites` | Favorites |
| POST | `/api/accounts/{id}/favorites` | Toggle favorite |

## Configuration

The server stores configuration in the database's `server_settings` table. You can also set environment variables:

- `CINEMATE_PORT` — server port (default: 9876)
- `CINEMATE_DB` — database path (default: `./cinemate.db`)
