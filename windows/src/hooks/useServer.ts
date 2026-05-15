import { createContext, useContext } from 'react';
import type { ServerConnection } from '../api/types';

export interface ServerContextType {
  connection: ServerConnection;
  setConnection: (conn: ServerConnection) => void;
  isOnline: boolean;
}

export const ServerContext = createContext<ServerContextType>({
  connection: { url: '', status: 'disconnected', offline: true },
  setConnection: () => {},
  isOnline: false,
});

export function useServer() {
  return useContext(ServerContext);
}
