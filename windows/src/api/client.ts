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
    return this.request<ServerInfo>('/api/ping');
  }

  // ─── Accounts ───

  async getAccounts(): Promise<Account[]> {
    return this.request<Account[]>('/api/accounts');
  }

  async createAccount(data: { name: string; avatar_color: string; pin?: string }): Promise<Account> {
    return this.request<Account>('/api/accounts', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async verifyPin(accountId: number, pin: string): Promise<boolean> {
    const res = await this.request<{ valid: boolean }>(`/api/accounts/${accountId}/verify-pin`, {
      method: 'POST',
      body: JSON.stringify({ pin }),
    });
    return res.valid;
  }

  // ─── Movies ───

  async getMovies(): Promise<Movie[]> {
    return this.request<Movie[]>('/api/movies');
  }

  async getMovie(id: number): Promise<Movie> {
    return this.request<Movie>(`/api/movies/${id}`);
  }

  async scanFolder(path: string): Promise<{ added: number }> {
    return this.request<{ added: number }>('/api/scan', {
      method: 'POST',
      body: JSON.stringify({ path }),
    });
  }

  // ─── TV Shows ───

  async getTVShows(): Promise<TVShow[]> {
    return this.request<TVShow[]>('/api/tv-shows');
  }

  async getTVShow(id: number): Promise<TVShow> {
    return this.request<TVShow>(`/api/tv-shows/${id}`);
  }

  // ─── Watch History ───

  async getWatchHistory(accountId: number): Promise<WatchHistory[]> {
    return this.request<WatchHistory[]>(`/api/accounts/${accountId}/history`);
  }

  async updateProgress(accountId: number, movieId: number, progress: number, completed: boolean): Promise<void> {
    await this.request(`/api/accounts/${accountId}/history`, {
      method: 'POST',
      body: JSON.stringify({ movie_id: movieId, progress, completed }),
    });
  }

  // ─── Favorites ───

  async getFavorites(accountId: number): Promise<Favorite[]> {
    return this.request<Favorite[]>(`/api/accounts/${accountId}/favorites`);
  }

  async toggleFavorite(accountId: number, movieId: number): Promise<{ favorited: boolean }> {
    return this.request<{ favorited: boolean }>(`/api/accounts/${accountId}/favorites`, {
      method: 'POST',
      body: JSON.stringify({ movie_id: movieId }),
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
    return this.request<ConnectedClient[]>('/api/admin/clients');
  }

  async kickClient(clientId: string): Promise<void> {
    await this.request(`/api/admin/clients/${clientId}`, { method: 'DELETE' });
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
    return this.request<MusicTrack[]>(`/api/accounts/${accountId}/music/favorites`);
  }

  async toggleMusicFavorite(accountId: number, trackId: number): Promise<{ favorited: boolean }> {
    return this.request<{ favorited: boolean }>(`/api/accounts/${accountId}/music/favorites/${trackId}`, {
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
    return this.request<MusicTrack[]>(`/api/accounts/${accountId}/music/recently-played`);
  }

  async getPlaylists(accountId: number): Promise<Playlist[]> {
    return this.request<Playlist[]>(`/api/accounts/${accountId}/playlists`);
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
      body: JSON.stringify({ track_id: trackId }),
    });
  }

  async getMusicQueue(accountId: number): Promise<MusicTrack[]> {
    return this.request<MusicTrack[]>(`/api/accounts/${accountId}/music/queue`);
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
    return this.request<BookItem[]>(`/api/books${qs ? '?' + qs : ''}`);
  }

  async getBookStats(): Promise<{ total_books: number; total_authors: number; format_breakdown: { format: string; count: number }[] }> {
    return this.request(`/api/books/stats`);
  }

  bookCoverUrl(bookId: number): string {
    return `${this.baseUrl}/api/books/${bookId}/cover`;
  }

  async toggleBookFavorite(accountId: number, bookId: number): Promise<void> {
    await this.request(`/api/books/accounts/${accountId}/books/${bookId}/favorite`, { method: 'POST' });
  }

  async markBookFinished(accountId: number, bookId: number): Promise<void> {
    await this.request(`/api/books/accounts/${accountId}/books/${bookId}/finished`, { method: 'POST' });
  }

  async getCurrentlyReading(accountId: number): Promise<BookItem[]> {
    return this.request<BookItem[]>(`/api/books/accounts/${accountId}/books/currently-reading`);
  }

  async getFinishedBooks(accountId: number): Promise<BookItem[]> {
    return this.request<BookItem[]>(`/api/books/accounts/${accountId}/books/finished`);
  }

  async getBookAuthors(): Promise<{ name: string; book_count: number }[]> {
    return this.request(`/api/books/authors`);
  }
}

export const api = new CinemateAPI();
