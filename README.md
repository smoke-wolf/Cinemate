is this vibecoded? yes. does it work? try it out;)

# Cinemate

A cross-platform personal media library — movies, TV shows, music, and books — with a server that ties it all together.

## Architecture

```
cinemate-v3/
├── server/      Python FastAPI media server
├── mac/         Native macOS app (SwiftUI)
├── windows/     Windows/Linux app (Electron + React + TypeScript)
└── ios/         iOS app (SwiftUI)
```

### Server
FastAPI backend with LAN discovery, multi-account support, and WebSocket real-time sync.

- **Movies & TV**: directory scanning, metadata extraction, thumbnail generation, HLS/range streaming
- **Music**: library scanning, album art, audio streaming with HTTP Range, waveform generation, per-account playlists/favorites/play history/queue
- **Books**: library scanning and reading progress
- **WAN**: optional remote access with security middleware

```bash
cd server
pip install -r requirements.txt
python3 -m uvicorn main:app --host 0.0.0.0 --port 9876 --reload
# API docs at http://localhost:9876/docs
```

### Mac App
Native SwiftUI app with a local music library (scans directories for audio files).

- Full music player with album art, play queue, shuffle, repeat
- Artist/album/playlist detail views with cross-navigation
- Playlist persistence, custom cover photos, editable descriptions
- Favorites and play count tracking across sessions
- Sort options (title, artist, album, duration, recently added) on tracks/artists/albums
- Keyboard shortcuts (space, arrows, cmd+F, volume) and system media key integration
- Context menus on tracks (play, queue, go to artist/album, add to playlist)
- Directory watcher for auto-detecting new audio files
- Movie and book tabs connected to the server

```bash
cd mac
bash build.sh    # builds to ~/Desktop/Cinemate.app
```

### Windows App
Electron + React + TypeScript + Tailwind CSS. Connects to the Cinemate server over LAN.

- Movie and TV show browsing with genre rows, search, quality filters
- Video player with progress tracking, continue watching, favorites
- Multi-account support with PIN protection
- LAN admin panel for managing connected clients
- Offline mode with local SQLite fallback

```bash
cd windows
npm install
npm run dev       # development
npm run build     # production build
```

## Quick Start

1. Start the server: `cd server && python3 -m uvicorn main:app --host 0.0.0.0 --port 9876`
2. Scan your media: hit the API at `/docs` or use a client app
3. Open a client app — it auto-discovers the server on your LAN

## License

MIT
