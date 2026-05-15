# Mac App Guide

The macOS client is a native SwiftUI app built with Swift Package Manager. It runs standalone for local music playback and connects to the Cinemate server for movies, TV shows, and books.

## Building

Requires macOS 14 (Sonoma) or later and Xcode command line tools.

```bash
cd mac
bash build.sh
```

This compiles the app and copies it to `~/Desktop/Cinemate.app`. Open it from there or move it to `/Applications`.

You can also open `mac/Cinemate.xcodeproj` in Xcode if you prefer the IDE.

## Music Player

The music tab is a standalone local player — it doesn't need the server. Point it at a directory containing audio files and it scans everything.

### Supported formats
`.mp3`, `.m4a`, `.flac`, `.aac`, `.wav`, `.ogg`, `.aiff`, `.wma`, `.opus`, `.alac`

### Library scanning
On first launch, you set your music directory. The app scans it recursively, reading metadata from ID3 tags (MP3), MP4 atoms (M4A/AAC), Vorbis comments (FLAC/OGG), and so on. Album art is extracted and cached.

A background watcher polls for new files every 5 seconds, so anything you drop into the folder shows up automatically.

### Navigation

The music tab has four sections accessible from the top:

- **Browse** — recently added albums, genre groupings
- **All Tracks** — every track in your library, sortable
- **Artists** — grid of artists, click to see their discography
- **Albums** — grid of albums, click for track listing
- **Playlists** — your playlists with custom covers

Clicking an artist name anywhere (in a track row, album view, etc.) takes you to that artist's page. Same for album names. There's a back button at the top to navigate back.

### Playback

- Click any track to play it
- "Play All" and "Shuffle" buttons on artist/album/playlist pages
- Now playing bar at the bottom with progress, album art, controls
- Queue panel (click the queue icon) with drag-to-reorder

### Keyboard shortcuts

| Key | Action |
|-----|--------|
| Space | Play / Pause |
| Right arrow | Next track |
| Left arrow | Previous track |
| Cmd + Up | Volume up |
| Cmd + Down | Volume down |
| Cmd + F | Focus search |
| Escape | Go back / close |

Media keys on your keyboard (play/pause, next, previous) also work through the system's MPRemoteCommandCenter.

### Playlists

- Create playlists from the Playlists tab
- Add tracks via right-click context menu on any track
- Set a custom cover photo (click the cover area in playlist view)
- Add descriptions (click "Add description..." in playlist view)
- Playlists persist in `~/.cinemate/playlists.json`

### Favorites & Stats

Heart a track to favorite it. Play counts and favorites are saved to `~/.cinemate/music_stats.json` and survive app restarts.

### Context menus

Right-click any track for:
- Play
- Add to Queue
- Go to Artist
- Go to Album
- Add to Playlist (submenu with all your playlists)
- Toggle Favorite

### Sorting

Each section (tracks, artists, albums) has sort pills at the top. Click a pill to sort by that field, click the active pill again to toggle ascending/descending.

- **Tracks**: Artist, Title, Album, Duration, Recently Added
- **Artists**: Name, Track Count, Album Count
- **Albums**: Name, Artist, Year, Track Count

## Movies, TV, Books

These tabs connect to the Cinemate server over the network. The app auto-discovers the server on your LAN. If the server isn't running, these tabs show connection prompts.

## Data Storage

| File | Contents |
|------|----------|
| `~/.cinemate/playlists.json` | Playlist definitions and track lists |
| `~/.cinemate/music_stats.json` | Favorites, play counts, last played timestamps |
| `~/.cinemate/playlist_covers/` | Custom playlist cover images |
