import { app, BrowserWindow, ipcMain, dialog, protocol, session } from 'electron';
import path from 'path';
import os from 'os';
import { setupIPC } from './ipc';

let mainWindow: BrowserWindow | null = null;

const VITE_DEV_SERVER_URL = process.env.VITE_DEV_SERVER_URL;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1024,
    minHeight: 700,
    frame: true,
    backgroundColor: '#0a0a0f',
    titleBarStyle: 'hidden',
    titleBarOverlay: {
      color: '#0a0a0f',
      symbolColor: '#9ca3af',
      height: 36,
    },
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    show: false,
  });

  mainWindow.once('ready-to-show', () => {
    mainWindow?.show();
  });

  if (VITE_DEV_SERVER_URL) {
    mainWindow.loadURL(VITE_DEV_SERVER_URL);
  } else {
    mainWindow.loadFile(path.join(__dirname, '../dist/index.html'));
  }

  mainWindow.webContents.on('will-navigate', (event, url) => {
    if (!url.startsWith('file://') && !url.startsWith('http://localhost')) {
      event.preventDefault();
    }
  });

  mainWindow.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

const SENSITIVE_PATHS = ['.ssh', '.aws', '.gnupg', '.config', '.env'];

function isPathAllowed(filePath: string): boolean {
  const resolved = path.resolve(filePath);
  const homeDir = os.homedir();

  for (const sensitive of SENSITIVE_PATHS) {
    if (resolved.startsWith(path.join(homeDir, sensitive))) return false;
  }

  return true;
}

function setupProtocol() {
  protocol.registerFileProtocol('cinemate', (request, callback) => {
    const decoded = decodeURIComponent(request.url.replace('cinemate://', ''));
    const resolved = path.resolve(decoded);

    if (resolved !== decoded && decoded.includes('..')) {
      callback({ statusCode: 403 } as any);
      return;
    }

    if (!isPathAllowed(resolved)) {
      callback({ statusCode: 403 } as any);
      return;
    }

    callback({ path: resolved });
  });
}

app.whenReady().then(() => {
  setupProtocol();
  setupIPC();

  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    callback({
      responseHeaders: {
        ...details.responseHeaders,
        'Content-Security-Policy': [
          "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self' http://* ws://*; img-src 'self' data: http://*; media-src 'self' http://* file: cinemate:; frame-src http://*",
        ],
      },
    });
  });

  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// IPC: Open directory picker
ipcMain.handle('select-directory', async () => {
  if (!mainWindow) return null;
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openDirectory'],
    title: 'Select Media Folder',
  });
  if (result.canceled || result.filePaths.length === 0) return null;
  return result.filePaths[0];
});

// IPC: Get absolute video file path for playback
ipcMain.handle('get-video-path', (_event, relativePath: string) => {
  return `file://${relativePath}`;
});
