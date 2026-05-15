# Windows/Linux App Guide

The desktop client is an Electron app with a React + TypeScript frontend styled with Tailwind CSS. It connects to the Cinemate server over your local network for all media browsing and playback.

## Building

Requires Node.js 18+.

```bash
cd windows
npm install
```

### Development
```bash
npm run dev
```
Opens the app in dev mode with hot reload.

### Production build
```bash
npm run build
```

This produces platform-specific installers:
- **Windows**: NSIS installer (`.exe`) in `release/`
- **macOS**: DMG in `release/`
- **Linux**: AppImage in `release/`

## Connecting to the server

On first launch, you'll see the server connection screen. The app tries to auto-discover a Cinemate server on your LAN. If it finds one, click to connect. You can also enter a server URL manually.

If no server is available, the app falls back to offline mode with a local SQLite database. You can scan folders directly and everything works locally.

## Features

### Browse
The home tab shows your library organized into rows:
- **Continue Watching** — movies you started but haven't finished
- **My Favorites** — movies you've hearted
- **Recently Added** — newest additions
- **Genre rows** — movies grouped by genre, largest genres first

### Movies
Click a movie card to see its detail sheet (metadata, description, quality, file size). Click "Play" to launch the video player.

The video player tracks your progress automatically. Close it and come back later — it'll offer to resume where you left off.

### TV Shows
Browse shows, expand seasons, play individual episodes. Progress is tracked per-episode.

### Filtering & Sorting
The sidebar has:
- **Sort by**: Title, Year, Date Added, Last Played, File Size
- **Quality filter**: All, 4K, 1080p, 720p

### Accounts
Multiple people can use the same Cinemate instance. Each account gets its own watch history, favorites, and progress. Accounts can optionally have a PIN.

### LAN Admin
The admin tab shows all connected clients (IP, device name, what they're watching, connection time). You can kick clients from here.

### Profile
View your watching stats — total watch time, movies watched, genre breakdown, quality distribution, top rated.

## Architecture

```
windows/
├── electron/          Electron main process + preload
│   ├── main.ts        Window creation, IPC handlers
│   ├── preload.ts     Context bridge (exposes APIs to renderer)
│   └── ipc.ts         IPC channel definitions
├── src/
│   ├── App.tsx         Root component, state management, routing
│   ├── api/
│   │   ├── client.ts   HTTP + WebSocket client for the server
│   │   └── types.ts    TypeScript interfaces
│   ├── components/     UI components
│   ├── hooks/          React context hooks (server, accounts, library)
│   ├── db/
│   │   └── local.ts    Offline SQLite fallback
│   └── styles/
│       └── globals.css Tailwind base + custom styles
├── package.json
├── vite.config.ts
├── tailwind.config.js
└── electron-builder.yml
```

## Offline mode

If the server isn't reachable, the app switches to offline mode automatically. In offline mode:
- Movies and shows are stored in a local SQLite database (via better-sqlite3)
- You can scan local folders directly
- Watch history and favorites are persisted locally
- When the server comes back online, you can reconnect

## Theming

The app uses a dark cinema theme defined in `tailwind.config.js`:
- Background: near-black (`#0a0a0f`)
- Cards/surfaces: dark gray tones
- Accent: gold (`#d4a017`)
- Text: white with gray secondary/dim variants
