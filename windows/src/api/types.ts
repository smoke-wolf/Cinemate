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

// ─── Music ───
export interface MusicTrack {
  id: number;
  title: string;
  artist: string;
  album: string;
  album_id?: number;
  genre?: string;
  duration: number;
  track_number?: number;
  disc_number?: number;
  year?: number;
  format?: string;
  bitrate?: number;
  sample_rate?: number;
  file_path?: string;
  date_added?: string;
}

export interface MusicAlbum {
  id: number;
  name: string;
  artist: string;
  year?: number;
  genre?: string;
  track_count?: number;
  total_duration?: number;
  tracks?: MusicTrack[];
}

export interface MusicArtist {
  artist: string;
  track_count: number;
  album_count: number;
  total_duration: number;
  albums?: { name: string; album_id: number; year?: number; tracks?: number }[];
}

export interface Playlist {
  id: number;
  account_id: number;
  name: string;
  description?: string;
  track_count?: number;
  created_at?: string;
  updated_at?: string;
  tracks?: MusicTrack[];
}

export interface MusicGenre {
  genre: string;
  count: number;
}

export interface MusicStats {
  total_tracks: number;
  total_albums: number;
  total_artists: number;
  total_duration: number;
  format_breakdown?: { format: string; count: number }[];
}

// ─── App State ───
export type AppScreen = 'splash' | 'server' | 'accounts' | 'main';
export type MainTab = 'browse' | 'tvshows' | 'music' | 'books' | 'favorites' | 'recent' | 'profile' | 'admin';

// ─── Books ───
export interface BookItem {
  id: number;
  title: string;
  author: string | null;
  genre: string | null;
  publisher: string | null;
  language: string | null;
  description: string | null;
  page_count: number;
  format: string;
  file_path: string;
  file_size: number;
  cover_path: string | null;
  year: number | null;
  date_added: string;
  reading_progress: number;
  current_page: number;
  favorite: boolean;
  finished: boolean;
}
export type SortOption = 'title' | 'year' | 'date_added' | 'last_played' | 'file_size';
export type QualityFilter = 'all' | '4k' | '1080p' | '720p';

export interface ServerConnection {
  url: string;
  status: 'disconnected' | 'connecting' | 'connected' | 'failed';
  offline: boolean;
  info?: ServerInfo;
}
