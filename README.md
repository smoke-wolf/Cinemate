is this vibecoded? yes. does it work? try it out;)

---

# Cinemate

Your own private media library. Movies, TV shows, music, books — all in one place, running on your own hardware.

Cinemate is a self-hosted media server with native clients for macOS, Windows, Linux, and iOS. You point it at your media folders, it scans everything, and you get a clean UI to browse and play it all. No subscriptions, no cloud, no tracking. Your files stay on your machine.

## What's in the box

**Server** — Python FastAPI backend that does the heavy lifting. Scans your directories, extracts metadata, generates thumbnails, streams video and audio with HTTP Range support, handles multiple user accounts, and syncs state over WebSocket. Auto-discoverable on your LAN via Zeroconf.

**Mac app** — Native SwiftUI. Has a full music player with album art, queue management, shuffle, keyboard shortcuts, and media key support. Also connects to the server for movies, TV, and books. Scans local directories for audio files and watches for new ones automatically.

**Windows/Linux app** — Electron + React + TypeScript + Tailwind. Connects to your Cinemate server and gives you movie/TV browsing with genre rows, quality filters, a video player with progress tracking, multi-account support, and an admin panel. Works offline with a local SQLite fallback.

**iOS app** — SwiftUI. Movies, music, books, TV shows. Connects to the server just like the desktop apps.

## Getting started

### 1. Start the server

```bash
cd server
pip install -r requirements.txt
python3 -m uvicorn main:app --host 0.0.0.0 --port 9876
```

That's it. API docs are at `http://localhost:9876/docs`. The server broadcasts itself on your LAN — client apps will find it automatically.

### 2. Pick a client

**macOS** (requires macOS 14+):
```bash
cd mac
bash build.sh
open ~/Desktop/Cinemate.app
```

**Windows/Linux**:
```bash
cd windows
npm install
npm run dev        # dev mode
npm run build      # production build
```

**iOS**: Open `ios/CinemateApp` in Xcode and run on your device.

### 3. Scan your media

Either hit the scan endpoint through the API docs, or use the "Scan Folder" button in any client app. Point it at your movie/music/book directories and Cinemate handles the rest — metadata extraction, thumbnail generation, album art, the whole thing.

## Features

### Music
- Full player with play/pause, skip, shuffle, repeat, volume
- Artist and album detail views — click an artist name anywhere and it takes you to their page
- Playlists with custom cover photos and descriptions
- Favorites and play counts that persist across sessions
- Sort by title, artist, album, duration, or recently added
- Keyboard shortcuts (space for play/pause, arrows for skip, Cmd+F for search)
- System media key integration (play/pause/next/prev from your keyboard)
- Right-click context menus on any track
- Queue panel with drag-to-reorder
- Auto-detects new audio files dropped into your library folder
- Waveform visualization (server-generated)
- Audio streaming with HTTP Range support

### Movies & TV
- Directory scanning with automatic metadata extraction
- Thumbnail generation
- Genre browsing, quality filters (4K/1080p/720p), search
- Video player with progress tracking and resume
- Continue watching, recently played, favorites
- Multi-account with optional PIN protection

### Books
- Library scanning for ePub and PDF
- Reading progress tracking

### Platform
- Multi-account support — everyone in the house gets their own profile
- LAN auto-discovery via Zeroconf
- WebSocket real-time sync between clients
- Optional WAN access with security middleware
- Works offline — Windows app falls back to local SQLite

## Project structure

```
server/          Python FastAPI — the brain
mac/             macOS app — SwiftUI + SwiftPM
windows/         Windows/Linux app — Electron + React + TS + Tailwind
ios/             iOS app — SwiftUI
```

## Server API

The server exposes a full REST API. Key endpoints:

| Endpoint | What it does |
|----------|-------------|
| `GET /api/music/tracks` | List tracks (filterable by artist, album, genre) |
| `GET /api/music/artists` | List artists with track/album counts |
| `GET /api/music/albums` | List albums (sortable by name, artist, year) |
| `GET /api/music/stream/{id}` | Stream audio with Range support |
| `GET /api/music/art/{album_id}` | Serve album artwork |
| `GET /api/music/waveform/{id}` | Generate waveform data |
| `GET /api/movies` | List all movies |
| `GET /api/tv-shows` | List TV shows with seasons/episodes |
| `POST /api/scan` | Scan a directory for movies |
| `POST /api/music/scan` | Scan a directory for music |
| `GET /api/accounts/{id}/playlists` | User's playlists |
| `POST /api/accounts/{id}/music/history` | Log a play event |
| `POST /api/accounts/{id}/music/favorites/{track_id}` | Toggle favorite |

Full interactive docs at `http://localhost:9876/docs` when the server is running.

## Tech stack

| Component | Stack |
|-----------|-------|
| Server | Python 3.9+, FastAPI, aiosqlite, Zeroconf, Mutagen, ffmpeg |
| Mac | Swift 5.9, SwiftUI, SwiftPM, SQLite.swift, AVFoundation |
| Windows | Electron, React 18, TypeScript, Tailwind CSS, Vite, better-sqlite3 |
| iOS | Swift, SwiftUI, AVFoundation |

## Requirements

- **Server**: Python 3.9+, ffmpeg (for thumbnails and waveforms)
- **Mac**: macOS 14+ (Sonoma), Xcode command line tools
- **Windows**: Node.js 18+
- **iOS**: Xcode 15+, iOS 17+

## License

MIT
