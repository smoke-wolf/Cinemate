import type {
  Account,
  Movie,
  TVShow,
  TVSeason,
  WatchHistory,
  Favorite,
  TimestampComment,
  LibraryStats,
} from '../api/types';
import { hashPin } from '../utils/pin';

const db = window.electronAPI?.db;

// ─── Accounts ───

export async function getAccounts(): Promise<Account[]> {
  if (!db) return [];
  return (await db.query('SELECT * FROM accounts ORDER BY name')) as Account[];
}

export async function createAccount(data: {
  name: string;
  avatar_color: string;
  pin?: string;
}): Promise<Account> {
  if (!db) throw new Error('No database available');
  const result = await db.run(
    'INSERT INTO accounts (name, avatar_color, pin) VALUES (?, ?, ?)',
    [data.name, data.avatar_color, data.pin || null]
  );
  return {
    id: result.lastInsertRowid,
    name: data.name,
    avatar_color: data.avatar_color,
    has_pin: !!data.pin,
  };
}

export async function verifyPin(accountId: number, pin: string): Promise<boolean> {
  if (!db) return false;
  const rows = (await db.query(
    'SELECT pin FROM accounts WHERE id = ?',
    [accountId]
  )) as { pin: string | null }[];
  if (rows.length === 0) return false;
  const hashedInput = await hashPin(pin);
  return rows[0].pin === hashedInput;
}

// ─── Movies ───

export async function getMovies(): Promise<Movie[]> {
  if (!db) return [];
  return (await db.query('SELECT * FROM movies ORDER BY date_added DESC')) as Movie[];
}

export async function getMovie(id: number): Promise<Movie | null> {
  if (!db) return null;
  const rows = (await db.query('SELECT * FROM movies WHERE id = ?', [id])) as Movie[];
  return rows[0] || null;
}

export async function addMovie(movie: Omit<Movie, 'id'>): Promise<number> {
  if (!db) return 0;
  const result = await db.run(
    `INSERT INTO movies (title, year, genre, description, rating, quality, format, duration, file_size, file_path, thumbnail_path)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      movie.title, movie.year || null, movie.genre || null, movie.description || null,
      movie.rating || null, movie.quality || null, movie.format || null,
      movie.duration || null, movie.file_size || null, movie.file_path,
      movie.thumbnail_path || null,
    ]
  );
  return result.lastInsertRowid;
}

// ─── TV Shows ───

export async function getTVShows(): Promise<TVShow[]> {
  if (!db) return [];
  const shows = (await db.query(`
    SELECT s.*,
      (SELECT COUNT(*) FROM tv_episodes WHERE show_id = s.id) as episode_count
    FROM tv_shows s ORDER BY name
  `)) as TVShow[];
  return shows;
}

export async function getTVShowWithSeasons(id: number): Promise<TVShow | null> {
  if (!db) return null;
  const shows = (await db.query('SELECT * FROM tv_shows WHERE id = ?', [id])) as TVShow[];
  if (shows.length === 0) return null;
  const show = shows[0];

  const episodes = (await db.query(
    'SELECT * FROM tv_episodes WHERE show_id = ? ORDER BY season, episode',
    [id]
  )) as any[];

  const seasonMap = new Map<number, any[]>();
  for (const ep of episodes) {
    if (!seasonMap.has(ep.season)) seasonMap.set(ep.season, []);
    seasonMap.get(ep.season)!.push(ep);
  }

  show.seasons = Array.from(seasonMap.entries()).map(([season, episodes]) => ({
    season,
    episodes,
  }));

  return show;
}

// ─── Watch History ───

export async function getWatchHistory(accountId: number): Promise<WatchHistory[]> {
  if (!db) return [];
  const rows = (await db.query(
    `SELECT wh.*, m.title, m.thumbnail_path, m.year, m.quality, m.genre, m.file_path, m.duration, m.file_size, m.format, m.description, m.rating, m.date_added
     FROM watch_history wh
     LEFT JOIN movies m ON wh.movie_id = m.id
     WHERE wh.account_id = ?
     ORDER BY wh.last_watched DESC`,
    [accountId]
  )) as any[];

  return rows.map((r: any) => ({
    id: r.id,
    account_id: r.account_id,
    movie_id: r.movie_id,
    episode_id: r.episode_id,
    progress: r.progress,
    completed: !!r.completed,
    last_watched: r.last_watched,
    movie: r.movie_id
      ? {
          id: r.movie_id,
          title: r.title,
          thumbnail_path: r.thumbnail_path,
          year: r.year,
          quality: r.quality,
          genre: r.genre,
          file_path: r.file_path,
          duration: r.duration,
          file_size: r.file_size,
          format: r.format,
          description: r.description,
          rating: r.rating,
          date_added: r.date_added,
        }
      : undefined,
  }));
}

export async function updateProgress(
  accountId: number,
  movieId: number,
  progress: number,
  completed: boolean
): Promise<void> {
  if (!db) return;
  const existing = (await db.query(
    'SELECT id FROM watch_history WHERE account_id = ? AND movie_id = ?',
    [accountId, movieId]
  )) as any[];

  if (existing.length > 0) {
    await db.run(
      'UPDATE watch_history SET progress = ?, completed = ?, last_watched = CURRENT_TIMESTAMP WHERE id = ?',
      [progress, completed ? 1 : 0, existing[0].id]
    );
  } else {
    await db.run(
      'INSERT INTO watch_history (account_id, movie_id, progress, completed) VALUES (?, ?, ?, ?)',
      [accountId, movieId, progress, completed ? 1 : 0]
    );
  }
}

// ─── Favorites ───

export async function getFavorites(accountId: number): Promise<Favorite[]> {
  if (!db) return [];
  const rows = (await db.query(
    `SELECT f.*, m.title, m.thumbnail_path, m.year, m.quality, m.genre, m.file_path, m.duration, m.file_size, m.format, m.description, m.rating, m.date_added
     FROM favorites f
     LEFT JOIN movies m ON f.movie_id = m.id
     WHERE f.account_id = ?
     ORDER BY f.added_at DESC`,
    [accountId]
  )) as any[];

  return rows.map((r: any) => ({
    id: r.id,
    account_id: r.account_id,
    movie_id: r.movie_id,
    show_id: r.show_id,
    added_at: r.added_at,
    movie: r.movie_id
      ? {
          id: r.movie_id,
          title: r.title,
          thumbnail_path: r.thumbnail_path,
          year: r.year,
          quality: r.quality,
          genre: r.genre,
          file_path: r.file_path,
          duration: r.duration,
          file_size: r.file_size,
          format: r.format,
          description: r.description,
          rating: r.rating,
          date_added: r.date_added,
        }
      : undefined,
  }));
}

export async function toggleFavorite(
  accountId: number,
  movieId: number
): Promise<boolean> {
  if (!db) return false;
  const existing = (await db.query(
    'SELECT id FROM favorites WHERE account_id = ? AND movie_id = ?',
    [accountId, movieId]
  )) as any[];

  if (existing.length > 0) {
    await db.run('DELETE FROM favorites WHERE id = ?', [existing[0].id]);
    return false;
  } else {
    await db.run(
      'INSERT INTO favorites (account_id, movie_id) VALUES (?, ?)',
      [accountId, movieId]
    );
    return true;
  }
}

export async function isFavorite(accountId: number, movieId: number): Promise<boolean> {
  if (!db) return false;
  const rows = (await db.query(
    'SELECT id FROM favorites WHERE account_id = ? AND movie_id = ?',
    [accountId, movieId]
  )) as any[];
  return rows.length > 0;
}

// ─── Timestamp Comments ───

export async function getComments(movieId: number): Promise<TimestampComment[]> {
  if (!db) return [];
  return (await db.query(
    `SELECT tc.*, a.name as account_name
     FROM timestamp_comments tc
     LEFT JOIN accounts a ON tc.account_id = a.id
     WHERE tc.movie_id = ?
     ORDER BY tc.timestamp_sec`,
    [movieId]
  )) as TimestampComment[];
}

export async function addComment(
  accountId: number,
  movieId: number,
  timestampSec: number,
  comment: string
): Promise<TimestampComment> {
  if (!db) throw new Error('No database');
  const result = await db.run(
    'INSERT INTO timestamp_comments (account_id, movie_id, timestamp_sec, comment) VALUES (?, ?, ?, ?)',
    [accountId, movieId, timestampSec, comment]
  );
  return {
    id: result.lastInsertRowid,
    account_id: accountId,
    movie_id: movieId,
    timestamp_sec: timestampSec,
    comment,
    created_at: new Date().toISOString(),
  };
}

// ─── Stats ───

export async function getStats(accountId: number): Promise<LibraryStats> {
  if (!db) {
    return {
      movie_count: 0,
      show_count: 0,
      total_watch_time: 0,
      movies_watched: 0,
      avg_rating: 0,
      genre_breakdown: [],
      quality_distribution: [],
      top_rated: [],
      recently_watched: [],
      favorite_genres: [],
    };
  }

  const movieCount = (await db.query('SELECT COUNT(*) as count FROM movies')) as any[];
  const showCount = (await db.query('SELECT COUNT(*) as count FROM tv_shows')) as any[];
  const watchedCount = (await db.query(
    'SELECT COUNT(*) as count FROM watch_history WHERE account_id = ? AND completed = 1',
    [accountId]
  )) as any[];

  const totalTime = (await db.query(
    `SELECT COALESCE(SUM(m.duration * wh.progress), 0) as total
     FROM watch_history wh
     JOIN movies m ON wh.movie_id = m.id
     WHERE wh.account_id = ?`,
    [accountId]
  )) as any[];

  const avgRating = (await db.query(
    'SELECT COALESCE(AVG(rating), 0) as avg FROM ratings WHERE account_id = ?',
    [accountId]
  )) as any[];

  const genres = (await db.query(
    `SELECT genre, COUNT(*) as count,
     (SELECT COUNT(*) FROM watch_history wh JOIN movies m2 ON wh.movie_id = m2.id WHERE wh.account_id = ? AND m2.genre = movies.genre AND wh.completed = 1) as watched
     FROM movies WHERE genre IS NOT NULL GROUP BY genre ORDER BY count DESC`,
    [accountId]
  )) as any[];

  const qualities = (await db.query(
    'SELECT quality, COUNT(*) as count FROM movies WHERE quality IS NOT NULL GROUP BY quality'
  )) as any[];

  const topRated = (await db.query(
    `SELECT m.*, r.rating as user_rating
     FROM ratings r JOIN movies m ON r.movie_id = m.id
     WHERE r.account_id = ?
     ORDER BY r.rating DESC LIMIT 10`,
    [accountId]
  )) as any[];

  const recentlyWatched = await getWatchHistory(accountId);

  const favGenres = (await db.query(
    `SELECT m.genre, COUNT(*) as cnt
     FROM favorites f JOIN movies m ON f.movie_id = m.id
     WHERE f.account_id = ? AND m.genre IS NOT NULL
     GROUP BY m.genre ORDER BY cnt DESC LIMIT 3`,
    [accountId]
  )) as any[];

  return {
    movie_count: movieCount[0]?.count || 0,
    show_count: showCount[0]?.count || 0,
    total_watch_time: totalTime[0]?.total || 0,
    movies_watched: watchedCount[0]?.count || 0,
    avg_rating: Math.round((avgRating[0]?.avg || 0) * 10) / 10,
    genre_breakdown: genres.map((g: any) => ({
      genre: g.genre,
      count: g.count,
      watched: g.watched,
    })),
    quality_distribution: qualities.map((q: any) => ({
      quality: q.quality,
      count: q.count,
    })),
    top_rated: topRated,
    recently_watched: recentlyWatched.slice(0, 10),
    favorite_genres: favGenres.map((g: any) => g.genre),
  };
}

// ─── Scan folder (stub for offline mode) ───

export async function scanFolder(folderPath: string): Promise<number> {
  // In offline mode, we just record the folder. Actual file scanning
  // would require fs access through IPC. This is a simplified version.
  if (!db) return 0;
  await db.run(
    'INSERT OR REPLACE INTO scan_folders (path, last_scanned) VALUES (?, CURRENT_TIMESTAMP)',
    [folderPath]
  );
  return 0;
}
