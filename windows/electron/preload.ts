import { contextBridge, ipcRenderer } from 'electron';

contextBridge.exposeInMainWorld('electronAPI', {
  selectDirectory: () => ipcRenderer.invoke('select-directory'),
  getVideoPath: (relativePath: string) => ipcRenderer.invoke('get-video-path', relativePath),
  db: {
    query: (sql: string, params?: unknown[]) => ipcRenderer.invoke('db-query', sql, params),
    run: (sql: string, params?: unknown[]) => ipcRenderer.invoke('db-run', sql, params),
    exec: (sql: string) => ipcRenderer.invoke('db-exec', sql),
  },
  store: {
    get: (key: string) => ipcRenderer.invoke('store-get', key),
    set: (key: string, value: unknown) => ipcRenderer.invoke('store-set', key, value),
  },
  platform: process.platform,
});
