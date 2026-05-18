import { contextBridge, ipcRenderer } from 'electron';

contextBridge.exposeInMainWorld('electronAPI', {
  selectDirectory: () => ipcRenderer.invoke('select-directory'),
  getVideoPath: (relativePath: string) => ipcRenderer.invoke('get-video-path', relativePath),
  db: {
    getAccounts: () => ipcRenderer.invoke('db-get-accounts'),
    createAccount: (name: string, avatarColor: string, pin: string | null) =>
      ipcRenderer.invoke('db-create-account', name, avatarColor, pin),
    getAccountPin: (accountId: number) => ipcRenderer.invoke('db-get-account-pin', accountId),

    getMovies: () => ipcRenderer.invoke('db-get-movies'),
    getMovie: (id: number) => ipcRenderer.invoke('db-get-movie', id),
    addMovie: (movie: {
      title: string; year: number | null; genre: string | null; description: string | null;
      rating: number | null; quality: string | null; format: string | null;
      duration: number | null; file_size: number | null; file_path: string; thumbnail_path: string | null;
    }) => ipcRenderer.invoke('db-add-movie', movie),

    getTVShows: () => ipcRenderer.invoke('db-get-tv-shows'),
    getTVShow: (id: number) => ipcRenderer.invoke('db-get-tv-show', id),
    getTVEpisodes: (showId: number) => ipcRenderer.invoke('db-get-tv-episodes', showId),

    getWatchHistory: (accountId: number) => ipcRenderer.invoke('db-get-watch-history', accountId),
    findWatchHistory: (accountId: number, movieId: number) =>
      ipcRenderer.invoke('db-find-watch-history', accountId, movieId),
    updateWatchProgress: (progress: number, completed: number, id: number) =>
      ipcRenderer.invoke('db-update-watch-progress', progress, completed, id),
    insertWatchHistory: (accountId: number, movieId: number, progress: number, completed: number) =>
      ipcRenderer.invoke('db-insert-watch-history', accountId, movieId, progress, completed),

    getFavorites: (accountId: number) => ipcRenderer.invoke('db-get-favorites', accountId),
    findFavorite: (accountId: number, movieId: number) =>
      ipcRenderer.invoke('db-find-favorite', accountId, movieId),
    deleteFavorite: (id: number) => ipcRenderer.invoke('db-delete-favorite', id),
    insertFavorite: (accountId: number, movieId: number) =>
      ipcRenderer.invoke('db-insert-favorite', accountId, movieId),

    getComments: (movieId: number) => ipcRenderer.invoke('db-get-comments', movieId),
    addComment: (accountId: number, movieId: number, timestampSec: number, comment: string) =>
      ipcRenderer.invoke('db-add-comment', accountId, movieId, timestampSec, comment),

    getMovieCount: () => ipcRenderer.invoke('db-get-movie-count'),
    getShowCount: () => ipcRenderer.invoke('db-get-show-count'),
    getWatchedCount: (accountId: number) => ipcRenderer.invoke('db-get-watched-count', accountId),
    getTotalWatchTime: (accountId: number) => ipcRenderer.invoke('db-get-total-watch-time', accountId),
    getAvgRating: (accountId: number) => ipcRenderer.invoke('db-get-avg-rating', accountId),
    getGenreBreakdown: (accountId: number) => ipcRenderer.invoke('db-get-genre-breakdown', accountId),
    getQualityDistribution: () => ipcRenderer.invoke('db-get-quality-distribution'),
    getTopRated: (accountId: number) => ipcRenderer.invoke('db-get-top-rated', accountId),
    getFavoriteGenres: (accountId: number) => ipcRenderer.invoke('db-get-favorite-genres', accountId),

    upsertScanFolder: (folderPath: string) => ipcRenderer.invoke('db-upsert-scan-folder', folderPath),
  },
  store: {
    get: (key: string) => ipcRenderer.invoke('store-get', key),
    set: (key: string, value: unknown) => ipcRenderer.invoke('store-set', key, value),
  },
  platform: process.platform,
});
