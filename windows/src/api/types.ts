// ─── Account ───
export interface Account {
  id: number;
  name: string;
  avatar_color: string;
  pin?: string | null;
  created_at?: string;
}

// ─── Movie ───
export interface Movie {
  id: number;
  title: string;
  year?: number;
  genre?: string;
  description?: string;
  rating?: number;
  quality?: string;
  format?: string;
  duration?: number;
  file_size?: number;
  file_path: string;
  thumbnail_path?: string;
  date_added?: string;
}

// ─── TV Show ───
export interface TVShow {
  id: number;
  name: string;
  genre?: string;
  description?: string;
  thumbnail_path?: string;
  date_added?: string;
  episode_count?: number;
  watched_count?: number;
  seasons?: TVSeason[];
}

export interface TVSeason {
  season: number;
  episodes: TVEpisode[];
}

export interface TVEpisode {
  id: number;
  show_id: number;
  season: number;
  episode: number;
  title?: string;
  file_path: string;
  duration?: number;
  file_size?: number;
  thumbnail_path?: string;
}

// ─── Watch History ───
export interface WatchHistory {
  id: number;
  account_id: number;
  movie_id?: number;
  episode_id?: number;
  progress: number;
  completed: boolean;
  last_watched: string;
  movie?: Movie;
  episode?: TVEpisode;
}

// ─── Favorite ───
export interface Favorite {
  id: number;
  account_id: number;
  movie_id?: number;
  show_id?: number;
  added_at: string;
  movie?: Movie;
  show?: TVShow;
}

// ─── Rating ───
export interface Rating {
  id: number;
  account_id: number;
  movie_id: number;
  rating: number;
  rated_at: string;
}

// ─── Timestamp Comment ───
export interface TimestampComment {
  id: number;
  account_id: number;
  movie_id?: number;
  episode_id?: number;
  timestamp_sec: number;
  comment: string;
  created_at: string;
  account_name?: string;
}

// ─── Server ───
export interface ServerInfo {
  name: string;
  url: string;
  version?: string;
  client_count?: number;
}

export interface ConnectedClient {
  id: string;
  ip: string;
  device_name: string;
  current_media?: string;
  connected_at: string;
  uptime: number;
}

// ─── Library Stats ───
export interface LibraryStats {
  movie_count: number;
  show_count: number;
  total_watch_time: number;
  movies_watched: number;
  avg_rating: number;
  genre_breakdown: { genre: string; count: number; watched: number }[];
  quality_distribution: { quality: string; count: number }[];
  top_rated: (Movie & { user_rating: number })[];
  recently_watched: WatchHistory[];
  favorite_genres: string[];
}

// ─── App State ───
export type AppScreen = 'splash' | 'server' | 'accounts' | 'main';
export type MainTab = 'browse' | 'tvshows' | 'favorites' | 'recent' | 'profile' | 'admin';
export type SortOption = 'title' | 'year' | 'date_added' | 'last_played' | 'file_size';
export type QualityFilter = 'all' | '4k' | '1080p' | '720p';

export interface ServerConnection {
  url: string;
  status: 'disconnected' | 'connecting' | 'connected' | 'failed';
  offline: boolean;
  info?: ServerInfo;
}
