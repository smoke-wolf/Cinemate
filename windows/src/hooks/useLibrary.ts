import { createContext, useContext } from 'react';
import type {
  Movie,
  TVShow,
  WatchHistory,
  Favorite,
  MainTab,
  SortOption,
  QualityFilter,
} from '../api/types';

export interface LibraryContextType {
  movies: Movie[];
  tvShows: TVShow[];
  watchHistory: WatchHistory[];
  favorites: Favorite[];
  activeTab: MainTab;
  setActiveTab: (tab: MainTab) => void;
  sortBy: SortOption;
  setSortBy: (sort: SortOption) => void;
  qualityFilter: QualityFilter;
  setQualityFilter: (filter: QualityFilter) => void;
  loadMovies: () => Promise<void>;
  loadTVShows: () => Promise<void>;
  loadWatchHistory: () => Promise<void>;
  loadFavorites: () => Promise<void>;
  toggleFavorite: (movieId: number) => Promise<void>;
  updateProgress: (movieId: number, progress: number, completed: boolean) => Promise<void>;
  scanFolder: () => Promise<void>;
  selectedMovie: Movie | null;
  setSelectedMovie: (movie: Movie | null) => void;
  playingMovie: Movie | null;
  setPlayingMovie: (movie: Movie | null) => void;
  musicTrackCount: number;
}

export const LibraryContext = createContext<LibraryContextType>({
  movies: [],
  tvShows: [],
  watchHistory: [],
  favorites: [],
  activeTab: 'browse',
  setActiveTab: () => {},
  sortBy: 'date_added',
  setSortBy: () => {},
  qualityFilter: 'all',
  setQualityFilter: () => {},
  loadMovies: async () => {},
  loadTVShows: async () => {},
  loadWatchHistory: async () => {},
  loadFavorites: async () => {},
  toggleFavorite: async () => {},
  updateProgress: async () => {},
  scanFolder: async () => {},
  selectedMovie: null,
  setSelectedMovie: () => {},
  playingMovie: null,
  setPlayingMovie: () => {},
  musicTrackCount: 0,
});

export function useLibrary() {
  return useContext(LibraryContext);
}
