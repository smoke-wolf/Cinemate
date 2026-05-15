import { ipcMain, app } from 'electron';
import path from 'path';
import fs from 'fs';

let db: any = null;
let storePath: string;
let store: Record<string, unknown> = {};

function getDB() {
  if (db) return db;
  try {
    const Database = require('better-sqlite3');
    const dbPath = path.join(app.getPath('userData'), 'cinemate.db');
    db = new Database(dbPath);
    db.pragma('journal_mode = WAL');
    initializeDB();
    return db;
  } catch (err) {
    console.error('Failed to initialize SQLite:', err);
    return null;
  }
}

function initializeDB() {
  if (!db) return;
  db.exec(`
    CREATE TABLE IF NOT EXISTS accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      avatar_color TEXT DEFAULT '#d4a017',
      pin TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS movies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      year INTEGER,
      genre TEXT,
      description TEXT,
      rating REAL,
      quality TEXT,
      format TEXT,
      duration INTEGER,
      file_size INTEGER,
      file_path TEXT NOT NULL,
      thumbnail_path TEXT,
      date_added DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS tv_shows (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      genre TEXT,
      description TEXT,
      thumbnail_path TEXT,
      date_added DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS tv_episodes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      show_id INTEGER NOT NULL,
      season INTEGER NOT NULL,
      episode INTEGER NOT NULL,
      title TEXT,
      file_path TEXT NOT NULL,
      duration INTEGER,
      file_size INTEGER,
      thumbnail_path TEXT,
      FOREIGN KEY (show_id) REFERENCES tv_shows(id)
    );

    CREATE TABLE IF NOT EXISTS watch_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL,
      movie_id INTEGER,
      episode_id INTEGER,
      progress REAL DEFAULT 0,
      completed INTEGER DEFAULT 0,
      last_watched DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (account_id) REFERENCES accounts(id),
      FOREIGN KEY (movie_id) REFERENCES movies(id),
      FOREIGN KEY (episode_id) REFERENCES tv_episodes(id)
    );

    CREATE TABLE IF NOT EXISTS favorites (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL,
      movie_id INTEGER,
      show_id INTEGER,
      added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (account_id) REFERENCES accounts(id),
      FOREIGN KEY (movie_id) REFERENCES movies(id),
      FOREIGN KEY (show_id) REFERENCES tv_shows(id)
    );

    CREATE TABLE IF NOT EXISTS ratings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL,
      movie_id INTEGER,
      rating REAL NOT NULL,
      rated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (account_id) REFERENCES accounts(id),
      FOREIGN KEY (movie_id) REFERENCES movies(id)
    );

    CREATE TABLE IF NOT EXISTS timestamp_comments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL,
      movie_id INTEGER,
      episode_id INTEGER,
      timestamp_sec REAL NOT NULL,
      comment TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (account_id) REFERENCES accounts(id),
      FOREIGN KEY (movie_id) REFERENCES movies(id),
      FOREIGN KEY (episode_id) REFERENCES tv_episodes(id)
    );

    CREATE TABLE IF NOT EXISTS scan_folders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      path TEXT NOT NULL UNIQUE,
      last_scanned DATETIME
    );
  `);
}

function loadStore() {
  storePath = path.join(app.getPath('userData'), 'cinemate-store.json');
  try {
    if (fs.existsSync(storePath)) {
      store = JSON.parse(fs.readFileSync(storePath, 'utf-8'));
    }
  } catch {
    store = {};
  }
}

function saveStore() {
  try {
    fs.writeFileSync(storePath, JSON.stringify(store, null, 2));
  } catch (err) {
    console.error('Failed to save store:', err);
  }
}

export function setupIPC() {
  loadStore();

  // Database operations
  ipcMain.handle('db-query', (_event, sql: string, params?: unknown[]) => {
    const database = getDB();
    if (!database) return [];
    try {
      const stmt = database.prepare(sql);
      return params ? stmt.all(...params) : stmt.all();
    } catch (err) {
      console.error('DB query error:', err);
      return [];
    }
  });

  ipcMain.handle('db-run', (_event, sql: string, params?: unknown[]) => {
    const database = getDB();
    if (!database) return { changes: 0, lastInsertRowid: 0 };
    try {
      const stmt = database.prepare(sql);
      const result = params ? stmt.run(...params) : stmt.run();
      return { changes: result.changes, lastInsertRowid: Number(result.lastInsertRowid) };
    } catch (err) {
      console.error('DB run error:', err);
      return { changes: 0, lastInsertRowid: 0 };
    }
  });

  ipcMain.handle('db-exec', (_event, sql: string) => {
    const database = getDB();
    if (!database) return;
    try {
      database.exec(sql);
    } catch (err) {
      console.error('DB exec error:', err);
    }
  });

  // Key-value store operations
  ipcMain.handle('store-get', (_event, key: string) => {
    return store[key] ?? null;
  });

  ipcMain.handle('store-set', (_event, key: string, value: unknown) => {
    store[key] = value;
    saveStore();
  });
}
