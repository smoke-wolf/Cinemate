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
} from './types';

class CinemateAPI {
  private baseUrl: string = '';
  private ws: WebSocket | null = null;
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
        setTimeout(() => this.connectWebSocket(), 5000);
      };
    } catch {}
  }

  disconnectWebSocket() {
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
}

export const api = new CinemateAPI();
