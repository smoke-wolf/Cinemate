/// <reference types="vite/client" />

interface Window {
  electronAPI: {
    selectDirectory: () => Promise<string | null>;
    getVideoPath: (relativePath: string) => string;
    db: {
      query: (sql: string, params?: unknown[]) => Promise<unknown[]>;
      run: (sql: string, params?: unknown[]) => Promise<{ changes: number; lastInsertRowid: number }>;
      exec: (sql: string) => Promise<void>;
    };
    store: {
      get: (key: string) => Promise<unknown>;
      set: (key: string, value: unknown) => Promise<void>;
    };
    platform: string;
  };
}
