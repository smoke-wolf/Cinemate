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

// --- Accounts ---

export async function getAccounts(): Promise<Account[]> {
  if (!db) return [];
  return (await db.getAccounts()) as Account[];
}

export async function createAccount(data: {
  name: string;
  avatar_color: string;
  pin?: string;
}): Promise<Account> {
  if (!db) throw new Error('No database available');
  const pinHash = data.pin ? await hashPin(data.pin) : null;
  const result = await db.createAccount(data.name, data.avatar_color, pinHash);
  return {
    id: result.lastInsertRowid,
    name: data.name,
    avatar_color: data.avatar_color,
    has_pin: !!data.pin,
  };
}

export async function verifyPin(accountId: number, pin: string): Promise<boolean> {
  if (!db) return false;
  const rows = (await db.getAccountPin(accountId)) as { pin: string | null }[];
  if (rows.length === 0) return false;
  const hashedInput = await hashPin(pin);
  return rows[0].pin === hashedInput;
}

// --- Movies ---

export async function getMovies(): Promise<Movie[]> {
  if (!db) return [];
  return (await db.getMovies()) as Movie[];
}

export async function getMovie(id: number): Promise<Movie | null> {
  if (!db) return null;
  const rows = (await db.getMovie(id)) as Movie[];
  return rows[0] || null;
}

export async function addMovie(movie: Omit<Movie, 'id'>): Promise<number> {
  if (!db) return 0;
  const result = await db.addMovie({
    title: movie.title,
    year: movie.year || null,
    genre: movie.genre || null,
    description: movie.description || null,
    rating: movie.rating || null,
    quality: movie.quality || null,
    format: movie.format || null,
    duration: movie.duration || null,
    file_size: movie.file_size || null,
    file_path: movie.file_path,
    thumbnail_path: movie.thumbnail_path || null,
  });
  return result.lastInsertRowid;
}

// --- TV Shows ---

export async function getTVShows(): Promise<TVShow[]> {
  if (!db) return [];
  return (await db.getTVShows()) as TVShow[];
}

export async function getTVShowWithSeasons(id: number): Promise<TVShow | null> {
  if (!db) return null;
  const shows = (await db.getTVShow(id)) as TVShow[];
  if (shows.length === 0) return null;
  const show = shows[0];

  const episodes = (await db.getTVEpisodes(id)) as any[];

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

// --- Watch History ---

export async function getWatchHistory(accountId: number): Promise<WatchHistory[]> {
  if (!db) return [];
  const rows = (await db.getWatchHistory(accountId)) as any[];

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
  const existing = (await db.findWatchHistory(accountId, movieId)) as any[];

  if (existing.length > 0) {
    await db.updateWatchProgress(progress, completed ? 1 : 0, existing[0].id);
  } else {
    await db.insertWatchHistory(accountId, movieId, progress, completed ? 1 : 0);
  }
}

// --- Favorites ---

export async function getFavorites(accountId: number): Promise<Favorite[]> {
  if (!db) return [];
  const rows = (await db.getFavorites(accountId)) as any[];

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
  const existing = (await db.findFavorite(accountId, movieId)) as any[];

  if (existing.length > 0) {
    await db.deleteFavorite(existing[0].id);
    return false;
  } else {
    await db.insertFavorite(accountId, movieId);
    return true;
  }
}

export async function isFavorite(accountId: number, movieId: number): Promise<boolean> {
  if (!db) return false;
  const rows = (await db.findFavorite(accountId, movieId)) as any[];
  return rows.length > 0;
}

// --- Timestamp Comments ---

export async function getComments(movieId: number): Promise<TimestampComment[]> {
  if (!db) return [];
  return (await db.getComments(movieId)) as TimestampComment[];
}

export async function addComment(
  accountId: number,
  movieId: number,
  timestampSec: number,
  comment: string
): Promise<TimestampComment> {
  if (!db) throw new Error('No database');
  const result = await db.addComment(accountId, movieId, timestampSec, comment);
  return {
    id: result.lastInsertRowid,
    account_id: accountId,
    movie_id: movieId,
    timestamp_sec: timestampSec,
    comment,
    created_at: new Date().toISOString(),
  };
}

// --- Stats ---

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

  const movieCount = (await db.getMovieCount()) as any[];
  const showCount = (await db.getShowCount()) as any[];
  const watchedCount = (await db.getWatchedCount(accountId)) as any[];
  const totalTime = (await db.getTotalWatchTime(accountId)) as any[];
  const avgRating = (await db.getAvgRating(accountId)) as any[];
  const genres = (await db.getGenreBreakdown(accountId)) as any[];
  const qualities = (await db.getQualityDistribution()) as any[];
  const topRated = (await db.getTopRated(accountId)) as any[];
  const recentlyWatched = await getWatchHistory(accountId);
  const favGenres = (await db.getFavoriteGenres(accountId)) as any[];

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

// --- Scan folder ---

export async function scanFolder(folderPath: string): Promise<number> {
  if (!db) return 0;
  await db.upsertScanFolder(folderPath);
  return 0;
}
