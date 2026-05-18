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

  function dbQuery(sql: string, params?: unknown[]): unknown[] {
    const database = getDB();
    if (!database) return [];
    try {
      const stmt = database.prepare(sql);
      return params ? stmt.all(...params) : stmt.all();
    } catch (err) {
      console.error('DB query error:', err);
      return [];
    }
  }

  function dbRun(sql: string, params?: unknown[]): { changes: number; lastInsertRowid: number } {
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
  }

  // --- Accounts ---

  ipcMain.handle('db-get-accounts', () => {
    return dbQuery('SELECT * FROM accounts ORDER BY name');
  });

  ipcMain.handle('db-create-account', (_event, name: string, avatarColor: string, pin: string | null) => {
    return dbRun(
      'INSERT INTO accounts (name, avatar_color, pin) VALUES (?, ?, ?)',
      [name, avatarColor, pin]
    );
  });

  ipcMain.handle('db-get-account-pin', (_event, accountId: number) => {
    return dbQuery('SELECT pin FROM accounts WHERE id = ?', [accountId]);
  });

  // --- Movies ---

  ipcMain.handle('db-get-movies', () => {
    return dbQuery('SELECT * FROM movies ORDER BY date_added DESC');
  });

  ipcMain.handle('db-get-movie', (_event, id: number) => {
    return dbQuery('SELECT * FROM movies WHERE id = ?', [id]);
  });

  ipcMain.handle('db-add-movie', (_event, movie: {
    title: string; year: number | null; genre: string | null; description: string | null;
    rating: number | null; quality: string | null; format: string | null;
    duration: number | null; file_size: number | null; file_path: string; thumbnail_path: string | null;
  }) => {
    return dbRun(
      `INSERT INTO movies (title, year, genre, description, rating, quality, format, duration, file_size, file_path, thumbnail_path)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        movie.title, movie.year, movie.genre, movie.description,
        movie.rating, movie.quality, movie.format,
        movie.duration, movie.file_size, movie.file_path, movie.thumbnail_path,
      ]
    );
  });

  // --- TV Shows ---

  ipcMain.handle('db-get-tv-shows', () => {
    return dbQuery(`
      SELECT s.*,
        (SELECT COUNT(*) FROM tv_episodes WHERE show_id = s.id) as episode_count
      FROM tv_shows s ORDER BY name
    `);
  });

  ipcMain.handle('db-get-tv-show', (_event, id: number) => {
    return dbQuery('SELECT * FROM tv_shows WHERE id = ?', [id]);
  });

  ipcMain.handle('db-get-tv-episodes', (_event, showId: number) => {
    return dbQuery(
      'SELECT * FROM tv_episodes WHERE show_id = ? ORDER BY season, episode',
      [showId]
    );
  });

  // --- Watch History ---

  ipcMain.handle('db-get-watch-history', (_event, accountId: number) => {
    return dbQuery(
      `SELECT wh.*, m.title, m.thumbnail_path, m.year, m.quality, m.genre, m.file_path, m.duration, m.file_size, m.format, m.description, m.rating, m.date_added
       FROM watch_history wh
       LEFT JOIN movies m ON wh.movie_id = m.id
       WHERE wh.account_id = ?
       ORDER BY wh.last_watched DESC`,
      [accountId]
    );
  });

  ipcMain.handle('db-find-watch-history', (_event, accountId: number, movieId: number) => {
    return dbQuery(
      'SELECT id FROM watch_history WHERE account_id = ? AND movie_id = ?',
      [accountId, movieId]
    );
  });

  ipcMain.handle('db-update-watch-progress', (_event, progress: number, completed: number, id: number) => {
    return dbRun(
      'UPDATE watch_history SET progress = ?, completed = ?, last_watched = CURRENT_TIMESTAMP WHERE id = ?',
      [progress, completed, id]
    );
  });

  ipcMain.handle('db-insert-watch-history', (_event, accountId: number, movieId: number, progress: number, completed: number) => {
    return dbRun(
      'INSERT INTO watch_history (account_id, movie_id, progress, completed) VALUES (?, ?, ?, ?)',
      [accountId, movieId, progress, completed]
    );
  });

  // --- Favorites ---

  ipcMain.handle('db-get-favorites', (_event, accountId: number) => {
    return dbQuery(
      `SELECT f.*, m.title, m.thumbnail_path, m.year, m.quality, m.genre, m.file_path, m.duration, m.file_size, m.format, m.description, m.rating, m.date_added
       FROM favorites f
       LEFT JOIN movies m ON f.movie_id = m.id
       WHERE f.account_id = ?
       ORDER BY f.added_at DESC`,
      [accountId]
    );
  });

  ipcMain.handle('db-find-favorite', (_event, accountId: number, movieId: number) => {
    return dbQuery(
      'SELECT id FROM favorites WHERE account_id = ? AND movie_id = ?',
      [accountId, movieId]
    );
  });

  ipcMain.handle('db-delete-favorite', (_event, id: number) => {
    return dbRun('DELETE FROM favorites WHERE id = ?', [id]);
  });

  ipcMain.handle('db-insert-favorite', (_event, accountId: number, movieId: number) => {
    return dbRun(
      'INSERT INTO favorites (account_id, movie_id) VALUES (?, ?)',
      [accountId, movieId]
    );
  });

  // --- Timestamp Comments ---

  ipcMain.handle('db-get-comments', (_event, movieId: number) => {
    return dbQuery(
      `SELECT tc.*, a.name as account_name
       FROM timestamp_comments tc
       LEFT JOIN accounts a ON tc.account_id = a.id
       WHERE tc.movie_id = ?
       ORDER BY tc.timestamp_sec`,
      [movieId]
    );
  });

  ipcMain.handle('db-add-comment', (_event, accountId: number, movieId: number, timestampSec: number, comment: string) => {
    return dbRun(
      'INSERT INTO timestamp_comments (account_id, movie_id, timestamp_sec, comment) VALUES (?, ?, ?, ?)',
      [accountId, movieId, timestampSec, comment]
    );
  });

  // --- Stats ---

  ipcMain.handle('db-get-movie-count', () => {
    return dbQuery('SELECT COUNT(*) as count FROM movies');
  });

  ipcMain.handle('db-get-show-count', () => {
    return dbQuery('SELECT COUNT(*) as count FROM tv_shows');
  });

  ipcMain.handle('db-get-watched-count', (_event, accountId: number) => {
    return dbQuery(
      'SELECT COUNT(*) as count FROM watch_history WHERE account_id = ? AND completed = 1',
      [accountId]
    );
  });

  ipcMain.handle('db-get-total-watch-time', (_event, accountId: number) => {
    return dbQuery(
      `SELECT COALESCE(SUM(m.duration * wh.progress), 0) as total
       FROM watch_history wh
       JOIN movies m ON wh.movie_id = m.id
       WHERE wh.account_id = ?`,
      [accountId]
    );
  });

  ipcMain.handle('db-get-avg-rating', (_event, accountId: number) => {
    return dbQuery(
      'SELECT COALESCE(AVG(rating), 0) as avg FROM ratings WHERE account_id = ?',
      [accountId]
    );
  });

  ipcMain.handle('db-get-genre-breakdown', (_event, accountId: number) => {
    return dbQuery(
      `SELECT genre, COUNT(*) as count,
       (SELECT COUNT(*) FROM watch_history wh JOIN movies m2 ON wh.movie_id = m2.id WHERE wh.account_id = ? AND m2.genre = movies.genre AND wh.completed = 1) as watched
       FROM movies WHERE genre IS NOT NULL GROUP BY genre ORDER BY count DESC`,
      [accountId]
    );
  });

  ipcMain.handle('db-get-quality-distribution', () => {
    return dbQuery(
      'SELECT quality, COUNT(*) as count FROM movies WHERE quality IS NOT NULL GROUP BY quality'
    );
  });

  ipcMain.handle('db-get-top-rated', (_event, accountId: number) => {
    return dbQuery(
      `SELECT m.*, r.rating as user_rating
       FROM ratings r JOIN movies m ON r.movie_id = m.id
       WHERE r.account_id = ?
       ORDER BY r.rating DESC LIMIT 10`,
      [accountId]
    );
  });

  ipcMain.handle('db-get-favorite-genres', (_event, accountId: number) => {
    return dbQuery(
      `SELECT m.genre, COUNT(*) as cnt
       FROM favorites f JOIN movies m ON f.movie_id = m.id
       WHERE f.account_id = ? AND m.genre IS NOT NULL
       GROUP BY m.genre ORDER BY cnt DESC LIMIT 3`,
      [accountId]
    );
  });

  // --- Scan Folders ---

  ipcMain.handle('db-upsert-scan-folder', (_event, folderPath: string) => {
    return dbRun(
      'INSERT OR REPLACE INTO scan_folders (path, last_scanned) VALUES (?, CURRENT_TIMESTAMP)',
      [folderPath]
    );
  });

  const ALLOWED_STORE_KEYS = ['lastServerUrl', 'theme', 'volume', 'lastAccount'];

  ipcMain.handle('store-get', (_event, key: string) => {
    if (!ALLOWED_STORE_KEYS.includes(key)) return null;
    return store[key] ?? null;
  });

  ipcMain.handle('store-set', (_event, key: string, value: unknown) => {
    if (!ALLOWED_STORE_KEYS.includes(key)) return;
    store[key] = value;
    saveStore();
  });
}
