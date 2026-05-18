/// <reference types="vite/client" />

interface Window {
  electronAPI: {
    selectDirectory: () => Promise<string | null>;
    getVideoPath: (relativePath: string) => string;
    db: {
      getAccounts: () => Promise<unknown[]>;
      createAccount: (name: string, avatarColor: string, pin: string | null) =>
        Promise<{ changes: number; lastInsertRowid: number }>;
      getAccountPin: (accountId: number) => Promise<unknown[]>;

      getMovies: () => Promise<unknown[]>;
      getMovie: (id: number) => Promise<unknown[]>;
      addMovie: (movie: {
        title: string; year: number | null; genre: string | null; description: string | null;
        rating: number | null; quality: string | null; format: string | null;
        duration: number | null; file_size: number | null; file_path: string; thumbnail_path: string | null;
      }) => Promise<{ changes: number; lastInsertRowid: number }>;

      getTVShows: () => Promise<unknown[]>;
      getTVShow: (id: number) => Promise<unknown[]>;
      getTVEpisodes: (showId: number) => Promise<unknown[]>;

      getWatchHistory: (accountId: number) => Promise<unknown[]>;
      findWatchHistory: (accountId: number, movieId: number) => Promise<unknown[]>;
      updateWatchProgress: (progress: number, completed: number, id: number) =>
        Promise<{ changes: number; lastInsertRowid: number }>;
      insertWatchHistory: (accountId: number, movieId: number, progress: number, completed: number) =>
        Promise<{ changes: number; lastInsertRowid: number }>;

      getFavorites: (accountId: number) => Promise<unknown[]>;
      findFavorite: (accountId: number, movieId: number) => Promise<unknown[]>;
      deleteFavorite: (id: number) => Promise<{ changes: number; lastInsertRowid: number }>;
      insertFavorite: (accountId: number, movieId: number) =>
        Promise<{ changes: number; lastInsertRowid: number }>;

      getComments: (movieId: number) => Promise<unknown[]>;
      addComment: (accountId: number, movieId: number, timestampSec: number, comment: string) =>
        Promise<{ changes: number; lastInsertRowid: number }>;

      getMovieCount: () => Promise<unknown[]>;
      getShowCount: () => Promise<unknown[]>;
      getWatchedCount: (accountId: number) => Promise<unknown[]>;
      getTotalWatchTime: (accountId: number) => Promise<unknown[]>;
      getAvgRating: (accountId: number) => Promise<unknown[]>;
      getGenreBreakdown: (accountId: number) => Promise<unknown[]>;
      getQualityDistribution: () => Promise<unknown[]>;
      getTopRated: (accountId: number) => Promise<unknown[]>;
      getFavoriteGenres: (accountId: number) => Promise<unknown[]>;

      upsertScanFolder: (folderPath: string) => Promise<{ changes: number; lastInsertRowid: number }>;
    };
    store: {
      get: (key: string) => Promise<unknown>;
      set: (key: string, value: unknown) => Promise<void>;
    };
    platform: string;
  };
}
