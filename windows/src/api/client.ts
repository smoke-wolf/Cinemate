import type {
  Account,
  Movie,
  TVShow,
  WatchHistory,
  Favorite,
  TimestampComment,
  LibraryStats,
  ConnectedClient,
  ServerInfo,
  MusicTrack,
  MusicAlbum,
  MusicArtist,
  MusicGenre,
  MusicStats,
  Playlist,
  BookItem,
} from './types';

class CinemateAPI {
  private baseUrl: string = '';
  private ws: WebSocket | null = null;
  private wsIntentionalClose: boolean = false;
  private listeners: Map<string, Set<(data: unknown) => void>> = new Map();

  setBaseUrl(url: string) {
    this.baseUrl = url.replace(/\/$/, '');
  }

  getBaseUrl(): string {
    return this.baseUrl;
  }

  // ─── WebSocket ───

  connectWebSocket() {
    if (this.ws) {
      this.ws.close();
    }
    this.wsIntentionalClose = false;
    const wsUrl = this.baseUrl.replace(/^http/, 'ws') + '/ws';
    try {
      this.ws = new WebSocket(wsUrl);
      this.ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data);
          const handlers = this.listeners.get(msg.type);
          if (handlers) {
            handlers.forEach((fn) => fn(msg.data));
          }
        } catch {}
      };
      this.ws.onclose = () => {
        if (!this.wsIntentionalClose) {
          setTimeout(() => this.connectWebSocket(), 5000);
        }
      };
    } catch {}
  }

  disconnectWebSocket() {
    this.wsIntentionalClose = true;
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  on(event: string, handler: (data: unknown) => void) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(handler);
    return () => this.listeners.get(event)?.delete(handler);
  }

  // ─── HTTP helpers ───

  private async request<T>(path: string, options?: RequestInit): Promise<T> {
    const res = await fetch(`${this.baseUrl}${path}`, {
      headers: { 'Content-Type': 'application/json' },
      ...options,
    });
    if (!res.ok) {
      throw new Error(`API error: ${res.status} ${res.statusText}`);
    }
    return res.json();
  }

  async ping(): Promise<ServerInfo> {
    return this.request<ServerInfo>('/api/server/info');
  }

  // ─── Accounts ───

  async getAccounts(): Promise<Account[]> {
    const data = await this.request<{ accounts: Account[] }>('/api/accounts');
    return data.accounts;
  }

  async createAccount(data: { name: string; avatar_color: string; pin?: string }): Promise<Account> {
    return this.request<Account>('/api/accounts', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async verifyPin(_accountId: number, _pin: string): Promise<boolean> {
    // Server does not expose a verify-pin endpoint; PIN verification is client-side
    // The server stores pin_hash but has no dedicated verification route
    return false;
  }

  // ─── Movies ───

  async getMovies(): Promise<Movie[]> {
    const data = await this.request<{ items: Movie[]; total: number }>('/api/library?media_type=movie&limit=1000');
    return data.items;
  }

  async getMovie(id: number): Promise<Movie> {
    return this.request<Movie>(`/api/library/${id}`);
  }

  async scanFolder(path: string): Promise<{ status: string; path: string }> {
    return this.request<{ status: string; path: string }>('/api/library/scan', {
      method: 'POST',
      body: JSON.stringify({ path }),
    });
  }

  // ─── TV Shows ───

  async getTVShows(): Promise<TVShow[]> {
    const data = await this.request<{ shows: Array<{
      show_name: string;
      total_episodes: number;
      total_seasons: number;
      seasons: Array<{
        season_number: number;
        episodes: Array<Record<string, unknown>>;
        episode_count: number;
      }>;
    }> }>('/api/shows');
    return data.shows.map((s) => ({
      id: 0,
      name: s.show_name,
      episode_count: s.total_episodes,
      seasons: s.seasons.map((sn) => ({
        season: sn.season_number,
        episodes: sn.episodes.map((ep: Record<string, unknown>) => ({
          id: ep.id as number,
          show_id: 0,
          season: ep.season_number as number,
          episode: ep.episode_number as number,
          title: ep.title as string,
          file_path: ep.file_path as string,
          duration: ep.duration as number,
          file_size: ep.file_size as number,
          thumbnail_path: ep.thumbnail_path as string,
        })),
      })),
    }));
  }

  async getTVShow(id: number): Promise<TVShow> {
    const shows = await this.getTVShows();
    const show = shows.find((s) => s.id === id);
    if (!show) throw new Error('Show not found');
    return show;
  }

  // ─── Watch History ───

  async getWatchHistory(accountId: number): Promise<WatchHistory[]> {
    const data = await this.request<{ items: WatchHistory[] }>(`/api/accounts/${accountId}/recently-played`);
    return data.items;
  }

  async updateProgress(accountId: number, mediaId: number, position: number, duration?: number): Promise<void> {
    const body: { position: number; duration?: number } = { position };
    if (duration !== undefined) body.duration = duration;
    await this.request(`/api/accounts/${accountId}/progress/${mediaId}`, {
      method: 'PUT',
      body: JSON.stringify(body),
    });
  }

  async markWatched(accountId: number, mediaId: number, watched: boolean = true): Promise<void> {
    await this.request(`/api/accounts/${accountId}/watched/${mediaId}`, {
      method: 'POST',
      body: JSON.stringify({ watched }),
    });
  }

  // ─── Favorites ───

  async getFavorites(accountId: number): Promise<Favorite[]> {
    return this.request<Favorite[]>(`/api/accounts/${accountId}/favorites`);
  }

  async toggleFavorite(accountId: number, mediaId: number): Promise<{ favorite: boolean }> {
    return this.request<{ favorite: boolean }>(`/api/accounts/${accountId}/favorites/${mediaId}`, {
      method: 'POST',
    });
  }

  // ─── Timestamp Comments ───

  async getComments(movieId: number): Promise<TimestampComment[]> {
    return this.request<TimestampComment[]>(`/api/movies/${movieId}/comments`);
  }

  async addComment(accountId: number, movieId: number, timestampSec: number, comment: string): Promise<TimestampComment> {
    return this.request<TimestampComment>(`/api/movies/${movieId}/comments`, {
      method: 'POST',
      body: JSON.stringify({ account_id: accountId, timestamp_sec: timestampSec, comment }),
    });
  }

  // ─── Stats ───

  async getStats(accountId: number): Promise<LibraryStats> {
    return this.request<LibraryStats>(`/api/accounts/${accountId}/stats`);
  }

  // ─── LAN Admin ───

  async getConnectedClients(): Promise<ConnectedClient[]> {
    const data = await this.request<{ connections: ConnectedClient[]; total: number }>('/api/admin/connections');
    return data.connections;
  }

  async kickClient(clientId: string): Promise<void> {
    await this.request(`/api/admin/kick/${clientId}`, { method: 'POST' });
  }

  // ─── Music Library ───

  async getMusicTracks(params?: {
    search?: string;
    sort?: string;
    order?: string;
    artist?: string;
    album?: string;
    genre?: string;
    limit?: number;
    offset?: number;
  }): Promise<{ items: MusicTrack[]; total: number; limit: number; offset: number }> {
    const qs = new URLSearchParams();
    if (params?.search) qs.set('search', params.search);
    if (params?.sort) qs.set('sort', params.sort);
    if (params?.order) qs.set('order', params.order);
    if (params?.artist) qs.set('artist', params.artist);
    if (params?.album) qs.set('album', params.album);
    if (params?.genre) qs.set('genre', params.genre);
    if (params?.limit) qs.set('limit', String(params.limit));
    if (params?.offset) qs.set('offset', String(params.offset));
    const query = qs.toString();
    return this.request(`/api/music/tracks${query ? `?${query}` : ''}`);
  }

  async getMusicArtists(params?: {
    search?: string;
    limit?: number;
    offset?: number;
  }): Promise<{ items: MusicArtist[]; total: number }> {
    const qs = new URLSearchParams();
    if (params?.search) qs.set('search', params.search);
    if (params?.limit) qs.set('limit', String(params.limit));
    if (params?.offset) qs.set('offset', String(params.offset));
    const query = qs.toString();
    return this.request(`/api/music/artists${query ? `?${query}` : ''}`);
  }

  async getMusicArtistDetail(name: string): Promise<MusicArtist> {
    return this.request<MusicArtist>(`/api/music/artists/${encodeURIComponent(name)}`);
  }

  async getMusicAlbums(params?: {
    search?: string;
    artist?: string;
    year?: number;
    sort?: string;
    order?: string;
  }): Promise<{ items: MusicAlbum[]; total: number }> {
    const qs = new URLSearchParams();
    if (params?.search) qs.set('search', params.search);
    if (params?.artist) qs.set('artist', params.artist);
    if (params?.year) qs.set('year', String(params.year));
    if (params?.sort) qs.set('sort', params.sort);
    if (params?.order) qs.set('order', params.order);
    const query = qs.toString();
    return this.request(`/api/music/albums${query ? `?${query}` : ''}`);
  }

  async getMusicAlbumDetail(id: number): Promise<MusicAlbum> {
    return this.request<MusicAlbum>(`/api/music/albums/${id}`);
  }

  async getMusicGenres(): Promise<{ genres: MusicGenre[] }> {
    return this.request<{ genres: MusicGenre[] }>('/api/music/genres');
  }

  async getMusicStats(): Promise<MusicStats> {
    return this.request<MusicStats>('/api/music/stats');
  }

  getMusicStreamUrl(trackId: number): string {
    return `${this.baseUrl}/api/music/stream/${trackId}`;
  }

  getMusicArtUrl(albumId: number): string {
    return `${this.baseUrl}/api/music/art/${albumId}`;
  }

  // ─── Music Per-Account ───

  async getMusicFavorites(accountId: number): Promise<MusicTrack[]> {
    const data = await this.request<{ items: MusicTrack[] }>(`/api/accounts/${accountId}/music/favorites`);
    return data.items;
  }

  async toggleMusicFavorite(accountId: number, trackId: number): Promise<{ favorite: boolean }> {
    return this.request<{ favorite: boolean }>(`/api/accounts/${accountId}/music/favorites/${trackId}`, {
      method: 'POST',
    });
  }

  async logMusicPlay(accountId: number, trackId: number, durationListened: number): Promise<void> {
    await this.request(`/api/accounts/${accountId}/music/history`, {
      method: 'POST',
      body: JSON.stringify({ track_id: trackId, duration_listened: durationListened }),
    });
  }

  async getRecentlyPlayedMusic(accountId: number): Promise<MusicTrack[]> {
    const data = await this.request<{ items: MusicTrack[] }>(`/api/accounts/${accountId}/music/recently-played`);
    return data.items;
  }

  async getPlaylists(accountId: number): Promise<Playlist[]> {
    const data = await this.request<{ playlists: Playlist[] }>(`/api/accounts/${accountId}/playlists`);
    return data.playlists;
  }

  async createPlaylist(accountId: number, data: { name: string; description?: string }): Promise<Playlist> {
    return this.request<Playlist>(`/api/accounts/${accountId}/playlists`, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async updatePlaylist(accountId: number, playlistId: number, data: { name?: string; description?: string }): Promise<Playlist> {
    return this.request<Playlist>(`/api/accounts/${accountId}/playlists/${playlistId}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  async deletePlaylist(accountId: number, playlistId: number): Promise<void> {
    await this.request(`/api/accounts/${accountId}/playlists/${playlistId}`, { method: 'DELETE' });
  }

  async addTrackToPlaylist(accountId: number, playlistId: number, trackId: number): Promise<void> {
    await this.request(`/api/accounts/${accountId}/playlists/${playlistId}/tracks`, {
      method: 'POST',
      body: JSON.stringify({ track_ids: [trackId] }),
    });
  }

  async getMusicQueue(accountId: number): Promise<MusicTrack[]> {
    const data = await this.request<{ queue: number[]; tracks: MusicTrack[] }>(`/api/accounts/${accountId}/music/queue`);
    return data.tracks;
  }

  async setMusicQueue(accountId: number, trackIds: number[]): Promise<void> {
    await this.request(`/api/accounts/${accountId}/music/queue`, {
      method: 'PUT',
      body: JSON.stringify({ track_ids: trackIds }),
    });
  }

  // ─── Books ───

  async getBooks(params?: { sort?: string; search?: string; format?: string }): Promise<BookItem[]> {
    const q = new URLSearchParams();
    if (params?.sort) q.set('sort', params.sort);
    if (params?.search) q.set('search', params.search);
    if (params?.format) q.set('format', params.format);
    const qs = q.toString();
    const data = await this.request<{ items: BookItem[]; total: number }>(`/api/books${qs ? '?' + qs : ''}`);
    return data.items;
  }

  async getBookStats(): Promise<{ total_books: number; total_authors: number; format_breakdown: { format: string; count: number }[] }> {
    return this.request(`/api/books/stats`);
  }

  bookCoverUrl(bookId: number): string {
    return `${this.baseUrl}/api/books/cover/${bookId}`;
  }

  async toggleBookFavorite(accountId: number, bookId: number): Promise<void> {
    await this.request(`/api/books/accounts/${accountId}/books/${bookId}/favorite`, { method: 'POST' });
  }

  async markBookFinished(accountId: number, bookId: number): Promise<void> {
    // Server marks a book as finished when reading_progress >= 0.95
    await this.request(`/api/books/accounts/${accountId}/books/${bookId}/progress`, {
      method: 'PUT',
      body: JSON.stringify({ progress: 1.0 }),
    });
  }

  async getCurrentlyReading(accountId: number): Promise<BookItem[]> {
    const data = await this.request<{ items: BookItem[] }>(`/api/books/accounts/${accountId}/books/currently-reading`);
    return data.items;
  }

  async getFinishedBooks(accountId: number): Promise<BookItem[]> {
    const data = await this.request<{ items: BookItem[] }>(`/api/books/accounts/${accountId}/books/finished`);
    return data.items;
  }

  async getBookAuthors(): Promise<{ author: string; book_count: number }[]> {
    const data = await this.request<{ authors: { author: string; book_count: number }[] }>(`/api/books/authors`);
    return data.authors;
  }
}

export const api = new CinemateAPI();
