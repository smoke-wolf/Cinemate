import React, { useState, useCallback, useEffect, useMemo, useRef } from 'react';
import { AnimatePresence } from 'framer-motion';
import type {
  AppScreen,
  MainTab,
  SortOption,
  QualityFilter,
  Account,
  Movie,
  TVShow,
  WatchHistory,
  Favorite,
  ServerConnection,
  MusicTrack,
} from './api/types';
import { api } from './api/client';
import * as localDb from './db/local';

import { ServerContext } from './hooks/useServer';
import { AccountContext } from './hooks/useAccounts';
import { LibraryContext } from './hooks/useLibrary';

import SplashScreen from './components/SplashScreen';
import ServerConnect from './components/ServerConnect';
import AccountSelector from './components/AccountSelector';
import Sidebar from './components/Sidebar';
import MovieRow from './components/MovieRow';
import MovieGrid from './components/MovieGrid';
import MovieDetailSheet from './components/MovieDetailSheet';
import VideoPlayer from './components/VideoPlayer';
import TVShowsView from './components/TVShowsView';
import ProfileView from './components/ProfileView';
import LANAdmin from './components/LANAdmin';
import MusicView from './components/MusicView';
import MusicPlayer from './components/MusicPlayer';
import BooksView from './components/BooksView';

export default function App() {
  // ─── Screen state ───
  const [screen, setScreen] = useState<AppScreen>('splash');

  // ─── Server ───
  const [connection, setConnection] = useState<ServerConnection>({
    url: '',
    status: 'disconnected',
    offline: true,
  });
  const isOnline = connection.status === 'connected' && !connection.offline;

  // ─── Accounts ───
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [currentAccount, setCurrentAccount] = useState<Account | null>(null);

  // ─── Library ───
  const [movies, setMovies] = useState<Movie[]>([]);
  const [tvShows, setTVShows] = useState<TVShow[]>([]);
  const [watchHistory, setWatchHistory] = useState<WatchHistory[]>([]);
  const [favorites, setFavorites] = useState<Favorite[]>([]);
  const [activeTab, setActiveTab] = useState<MainTab>('browse');
  const [sortBy, setSortBy] = useState<SortOption>('date_added');
  const [qualityFilter, setQualityFilter] = useState<QualityFilter>('all');
  const [selectedMovie, setSelectedMovie] = useState<Movie | null>(null);
  const [playingMovie, setPlayingMovie] = useState<Movie | null>(null);

  // ─── Music state ───
  const [musicTrackCount, setMusicTrackCount] = useState(0);
  const [musicCurrentTrack, setMusicCurrentTrack] = useState<MusicTrack | null>(null);
  const [musicQueue, setMusicQueue] = useState<MusicTrack[]>([]);
  const [musicQueueIndex, setMusicQueueIndex] = useState(0);
  const [musicIsPlaying, setMusicIsPlaying] = useState(false);
  const [showMusicQueue, setShowMusicQueue] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  // ─── Data loading ───

  const loadAccounts = useCallback(async () => {
    try {
      if (isOnline) {
        setAccounts(await api.getAccounts());
      } else {
        setAccounts(await localDb.getAccounts());
      }
    } catch {
      setAccounts([]);
    }
  }, [isOnline]);

  const createAccountFn = useCallback(
    async (data: { name: string; avatar_color: string; pin?: string }) => {
      if (isOnline) {
        return api.createAccount(data);
      } else {
        return localDb.createAccount(data);
      }
    },
    [isOnline]
  );

  const loadMovies = useCallback(async () => {
    try {
      if (isOnline) {
        setMovies(await api.getMovies());
      } else {
        setMovies(await localDb.getMovies());
      }
    } catch {
      setMovies([]);
    }
  }, [isOnline]);

  const loadTVShows = useCallback(async () => {
    try {
      if (isOnline) {
        setTVShows(await api.getTVShows());
      } else {
        setTVShows(await localDb.getTVShows());
      }
    } catch {
      setTVShows([]);
    }
  }, [isOnline]);

  const loadWatchHistory = useCallback(async () => {
    if (!currentAccount) return;
    try {
      if (isOnline) {
        setWatchHistory(await api.getWatchHistory(currentAccount.id));
      } else {
        setWatchHistory(await localDb.getWatchHistory(currentAccount.id));
      }
    } catch {
      setWatchHistory([]);
    }
  }, [isOnline, currentAccount]);

  const loadFavorites = useCallback(async () => {
    if (!currentAccount) return;
    try {
      if (isOnline) {
        setFavorites(await api.getFavorites(currentAccount.id));
      } else {
        setFavorites(await localDb.getFavorites(currentAccount.id));
      }
    } catch {
      setFavorites([]);
    }
  }, [isOnline, currentAccount]);

  const toggleFavoriteFn = useCallback(
    async (movieId: number) => {
      if (!currentAccount) return;
      try {
        if (isOnline) {
          await api.toggleFavorite(currentAccount.id, movieId);
        } else {
          await localDb.toggleFavorite(currentAccount.id, movieId);
        }
        await loadFavorites();
      } catch {}
    },
    [isOnline, currentAccount, loadFavorites]
  );

  const updateProgressFn = useCallback(
    async (movieId: number, progress: number, completed: boolean) => {
      if (!currentAccount) return;
      try {
        if (isOnline) {
          await api.updateProgress(currentAccount.id, movieId, progress, completed);
        } else {
          await localDb.updateProgress(currentAccount.id, movieId, progress, completed);
        }
        await loadWatchHistory();
      } catch {}
    },
    [isOnline, currentAccount, loadWatchHistory]
  );

  const scanFolderFn = useCallback(async () => {
    if (!window.electronAPI?.selectDirectory) return;
    const dir = await window.electronAPI.selectDirectory();
    if (!dir) return;
    try {
      if (isOnline) {
        await api.scanFolder(dir);
      } else {
        await localDb.scanFolder(dir);
      }
      await loadMovies();
      await loadTVShows();
    } catch {}
  }, [isOnline, loadMovies, loadTVShows]);

  // ─── Music loading ───
  const loadMusicStats = useCallback(async () => {
    if (!isOnline) return;
    try {
      const stats = await api.getMusicStats();
      setMusicTrackCount(stats.total_tracks);
    } catch {
      setMusicTrackCount(0);
    }
  }, [isOnline]);

  // Music player controls
  const musicPlayTrack = useCallback((track: MusicTrack, queue?: MusicTrack[]) => {
    const q = queue || [track];
    const idx = q.findIndex((t) => t.id === track.id);
    setMusicQueue(q);
    setMusicQueueIndex(idx >= 0 ? idx : 0);
    setMusicCurrentTrack(track);
    setMusicIsPlaying(true);

    // Set audio src and play
    if (audioRef.current) {
      audioRef.current.src = api.getMusicStreamUrl(track.id);
      audioRef.current.play().catch(() => {});
    }
  }, []);

  const musicTogglePlayPause = useCallback(() => {
    const audio = audioRef.current;
    if (!audio || !musicCurrentTrack) return;
    if (audio.paused) {
      audio.play().catch(() => {});
      setMusicIsPlaying(true);
    } else {
      audio.pause();
      setMusicIsPlaying(false);
    }
  }, [musicCurrentTrack]);

  const musicPlayNext = useCallback(() => {
    if (musicQueue.length === 0) return;
    const nextIdx = (musicQueueIndex + 1) % musicQueue.length;
    const nextTrack = musicQueue[nextIdx];
    setMusicQueueIndex(nextIdx);
    setMusicCurrentTrack(nextTrack);
    setMusicIsPlaying(true);
    if (audioRef.current) {
      audioRef.current.src = api.getMusicStreamUrl(nextTrack.id);
      audioRef.current.play().catch(() => {});
    }
  }, [musicQueue, musicQueueIndex]);

  const musicPlayPrev = useCallback(() => {
    if (musicQueue.length === 0) return;
    // If more than 3s in, restart current track
    if (audioRef.current && audioRef.current.currentTime > 3) {
      audioRef.current.currentTime = 0;
      return;
    }
    const prevIdx = (musicQueueIndex - 1 + musicQueue.length) % musicQueue.length;
    const prevTrack = musicQueue[prevIdx];
    setMusicQueueIndex(prevIdx);
    setMusicCurrentTrack(prevTrack);
    setMusicIsPlaying(true);
    if (audioRef.current) {
      audioRef.current.src = api.getMusicStreamUrl(prevTrack.id);
      audioRef.current.play().catch(() => {});
    }
  }, [musicQueue, musicQueueIndex]);

  const musicOnTrackEnd = useCallback(() => {
    musicPlayNext();
  }, [musicPlayNext]);

  const musicOnTimeUpdate = useCallback((_currentTime: number, _duration: number) => {
    // Placeholder for future use (scrobbling, etc.)
  }, []);

  // Load data when account is selected
  useEffect(() => {
    if (screen === 'main' && currentAccount) {
      loadMovies();
      loadTVShows();
      loadWatchHistory();
      loadFavorites();
      loadMusicStats();
    }
  }, [screen, currentAccount, loadMovies, loadTVShows, loadWatchHistory, loadFavorites, loadMusicStats]);

  // ─── Computed data ───

  const favoriteIds = useMemo(() => {
    return new Set(favorites.filter((f) => f.movie_id).map((f) => f.movie_id!));
  }, [favorites]);

  const progressMap = useMemo(() => {
    const map = new Map<number, number>();
    for (const wh of watchHistory) {
      if (wh.movie_id) {
        map.set(wh.movie_id, wh.progress);
      }
    }
    return map;
  }, [watchHistory]);

  // Sort and filter movies
  const sortedFilteredMovies = useMemo(() => {
    let filtered = [...movies];

    // Quality filter
    if (qualityFilter !== 'all') {
      filtered = filtered.filter((m) => {
        const q = m.quality?.toLowerCase();
        if (qualityFilter === '4k') return q === '4k' || q === '2160p';
        return q === qualityFilter;
      });
    }

    // Sort
    filtered.sort((a, b) => {
      switch (sortBy) {
        case 'title':
          return (a.title || '').localeCompare(b.title || '');
        case 'year':
          return (b.year || 0) - (a.year || 0);
        case 'date_added':
          return (b.date_added || '').localeCompare(a.date_added || '');
        case 'last_played': {
          const pa = progressMap.get(a.id) ? 1 : 0;
          const pb = progressMap.get(b.id) ? 1 : 0;
          return pb - pa;
        }
        case 'file_size':
          return (b.file_size || 0) - (a.file_size || 0);
        default:
          return 0;
      }
    });

    return filtered;
  }, [movies, sortBy, qualityFilter, progressMap]);

  // Group movies by genre for browse tab
  const genreRows = useMemo(() => {
    const genreMap = new Map<string, Movie[]>();
    for (const m of sortedFilteredMovies) {
      const genre = m.genre || 'Unknown';
      if (!genreMap.has(genre)) genreMap.set(genre, []);
      genreMap.get(genre)!.push(m);
    }
    return Array.from(genreMap.entries())
      .filter(([_, movies]) => movies.length > 0)
      .sort((a, b) => b[1].length - a[1].length);
  }, [sortedFilteredMovies]);

  const continueWatching = useMemo(() => {
    return watchHistory
      .filter((wh) => wh.movie && wh.progress > 0 && wh.progress < 0.9)
      .map((wh) => wh.movie!)
      .slice(0, 20);
  }, [watchHistory]);

  const recentlyAdded = useMemo(() => {
    return [...sortedFilteredMovies].slice(0, 20);
  }, [sortedFilteredMovies]);

  const favoriteMovies = useMemo(() => {
    return favorites.filter((f) => f.movie).map((f) => f.movie!);
  }, [favorites]);

  const recentlyPlayed = useMemo(() => {
    return watchHistory
      .filter((wh) => wh.movie)
      .map((wh) => wh.movie!)
      .slice(0, 20);
  }, [watchHistory]);

  // ─── Contexts ───

  const serverCtx = useMemo(
    () => ({ connection, setConnection, isOnline }),
    [connection, isOnline]
  );

  const accountCtx = useMemo(
    () => ({
      accounts,
      currentAccount,
      setCurrentAccount,
      loadAccounts,
      createAccount: createAccountFn,
    }),
    [accounts, currentAccount, loadAccounts, createAccountFn]
  );

  const libraryCtx = useMemo(
    () => ({
      movies: sortedFilteredMovies,
      tvShows,
      watchHistory,
      favorites,
      activeTab,
      setActiveTab,
      sortBy,
      setSortBy,
      qualityFilter,
      setQualityFilter,
      loadMovies,
      loadTVShows,
      loadWatchHistory,
      loadFavorites,
      toggleFavorite: toggleFavoriteFn,
      updateProgress: updateProgressFn,
      scanFolder: scanFolderFn,
      selectedMovie,
      setSelectedMovie,
      playingMovie,
      setPlayingMovie,
      musicTrackCount,
    }),
    [
      sortedFilteredMovies, tvShows, watchHistory, favorites,
      activeTab, sortBy, qualityFilter,
      loadMovies, loadTVShows, loadWatchHistory, loadFavorites,
      toggleFavoriteFn, updateProgressFn, scanFolderFn,
      selectedMovie, playingMovie, musicTrackCount,
    ]
  );

  // ─── Render ───

  return (
    <ServerContext.Provider value={serverCtx}>
      <AccountContext.Provider value={accountCtx}>
        <LibraryContext.Provider value={libraryCtx}>
          <div className="w-full h-full bg-cinema-bg text-white overflow-hidden">
            {/* Title bar drag region */}
            <div className="drag-region absolute top-0 left-0 right-0 h-9 z-40" />

            <AnimatePresence mode="wait">
              {screen === 'splash' && (
                <SplashScreen
                  key="splash"
                  onComplete={() => setScreen('server')}
                />
              )}

              {screen === 'server' && (
                <ServerConnect
                  key="server"
                  onConnect={() => setScreen('accounts')}
                />
              )}

              {screen === 'accounts' && (
                <AccountSelector
                  key="accounts"
                  onSelect={() => setScreen('main')}
                />
              )}

              {screen === 'main' && (
                <div key="main" className="flex h-full">
                  <Sidebar />
                  <main className="flex-1 overflow-hidden">
                    {/* Browse tab */}
                    {activeTab === 'browse' && (
                      <div className="h-full overflow-y-auto p-6">
                        {continueWatching.length > 0 && (
                          <MovieRow
                            title="Continue Watching"
                            movies={continueWatching}
                            onMovieClick={setSelectedMovie}
                            onMoviePlay={setPlayingMovie}
                            onMovieFavorite={(m) => toggleFavoriteFn(m.id)}
                            favoriteIds={favoriteIds}
                            progressMap={progressMap}
                          />
                        )}

                        {favoriteMovies.length > 0 && (
                          <MovieRow
                            title="My Favorites"
                            movies={favoriteMovies}
                            onMovieClick={setSelectedMovie}
                            onMoviePlay={setPlayingMovie}
                            onMovieFavorite={(m) => toggleFavoriteFn(m.id)}
                            favoriteIds={favoriteIds}
                            progressMap={progressMap}
                          />
                        )}

                        <MovieRow
                          title="Recently Added"
                          movies={recentlyAdded}
                          onMovieClick={setSelectedMovie}
                          onMoviePlay={setPlayingMovie}
                          onMovieFavorite={(m) => toggleFavoriteFn(m.id)}
                          favoriteIds={favoriteIds}
                          progressMap={progressMap}
                        />

                        {genreRows.map(([genre, genreMovies]) => (
                          <MovieRow
                            key={genre}
                            title={genre}
                            movies={genreMovies}
                            onMovieClick={setSelectedMovie}
                            onMoviePlay={setPlayingMovie}
                            onMovieFavorite={(m) => toggleFavoriteFn(m.id)}
                            favoriteIds={favoriteIds}
                            progressMap={progressMap}
                          />
                        ))}

                        {sortedFilteredMovies.length === 0 && (
                          <div className="flex flex-col items-center justify-center h-[60vh] text-cinema-text-dim">
                            <svg className="w-20 h-20 mb-4 opacity-20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
                            </svg>
                            <p className="text-lg font-medium mb-1">Your library is empty</p>
                            <p className="text-sm">Scan a folder to add movies</p>
                          </div>
                        )}
                      </div>
                    )}

                    {/* TV Shows tab */}
                    {activeTab === 'tvshows' && <TVShowsView />}

                    {/* Music tab */}
                    {activeTab === 'music' && (
                      <MusicView onPlayTrack={musicPlayTrack} />
                    )}

                    {/* Books tab */}
                    {activeTab === 'books' && <BooksView />}

                    {/* Favorites tab */}
                    {activeTab === 'favorites' && (
                      <div className="h-full overflow-y-auto p-6">
                        <MovieGrid
                          title="Favorites"
                          movies={favoriteMovies}
                          onMovieClick={setSelectedMovie}
                          onMoviePlay={setPlayingMovie}
                          onMovieFavorite={(m) => toggleFavoriteFn(m.id)}
                          favoriteIds={favoriteIds}
                          progressMap={progressMap}
                          emptyMessage="No favorites yet. Heart a movie to add it here."
                        />
                      </div>
                    )}

                    {/* Recently Played tab */}
                    {activeTab === 'recent' && (
                      <div className="h-full overflow-y-auto p-6">
                        <MovieGrid
                          title="Recently Played"
                          movies={recentlyPlayed}
                          onMovieClick={setSelectedMovie}
                          onMoviePlay={setPlayingMovie}
                          onMovieFavorite={(m) => toggleFavoriteFn(m.id)}
                          favoriteIds={favoriteIds}
                          progressMap={progressMap}
                          emptyMessage="Nothing played yet. Start watching something!"
                        />
                      </div>
                    )}

                    {/* Profile tab */}
                    {activeTab === 'profile' && <ProfileView />}

                    {/* LAN Admin tab */}
                    {activeTab === 'admin' && <LANAdmin />}
                  </main>
                </div>
              )}
            </AnimatePresence>

            {/* Movie detail sheet (modal) */}
            <AnimatePresence>
              {selectedMovie && (
                <MovieDetailSheet
                  movie={selectedMovie}
                  onClose={() => setSelectedMovie(null)}
                  onPlay={() => {
                    setPlayingMovie(selectedMovie);
                    setSelectedMovie(null);
                  }}
                  isFavorited={favoriteIds.has(selectedMovie.id)}
                  onToggleFavorite={() => toggleFavoriteFn(selectedMovie.id)}
                  progress={progressMap.get(selectedMovie.id)}
                />
              )}
            </AnimatePresence>

            {/* Video player (full window) */}
            <AnimatePresence>
              {playingMovie && (
                <VideoPlayer
                  movie={playingMovie}
                  onClose={() => {
                    setPlayingMovie(null);
                    loadWatchHistory();
                  }}
                  initialProgress={progressMap.get(playingMovie.id)}
                />
              )}
            </AnimatePresence>

            {/* Hidden audio element for music playback */}
            <audio ref={audioRef} preload="auto" />

            {/* Music player bar (global, fixed bottom) */}
            <AnimatePresence>
              {musicCurrentTrack && (
                <MusicPlayer
                  currentTrack={musicCurrentTrack}
                  queue={musicQueue}
                  queueIndex={musicQueueIndex}
                  isPlaying={musicIsPlaying}
                  onPlayPause={musicTogglePlayPause}
                  onNext={musicPlayNext}
                  onPrev={musicPlayPrev}
                  onTrackEnd={musicOnTrackEnd}
                  onTimeUpdate={musicOnTimeUpdate}
                  audioRef={audioRef}
                  showQueue={showMusicQueue}
                  onToggleQueue={() => setShowMusicQueue((v) => !v)}
                />
              )}
            </AnimatePresence>
          </div>
        </LibraryContext.Provider>
      </AccountContext.Provider>
    </ServerContext.Provider>
  );
}
