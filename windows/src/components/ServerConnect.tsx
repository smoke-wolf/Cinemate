import React, { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useServer } from '../hooks/useServer';
import { api } from '../api/client';

interface ServerConnectProps {
  onConnect: () => void;
}

interface DiscoveredServer {
  name: string;
  url: string;
}

function PulsingDot({ color }: { color: string }) {
  return (
    <span className="relative flex h-2 w-2">
      <span className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 ${color}`} />
      <span className={`relative inline-flex rounded-full h-2 w-2 ${color}`} />
    </span>
  );
}

export default function ServerConnect({ onConnect }: ServerConnectProps) {
  const { connection, setConnection } = useServer();
  const [serverUrl, setServerUrl] = useState('http://localhost:9876');
  const [error, setError] = useState('');
  const [discoveredServers, setDiscoveredServers] = useState<DiscoveredServer[]>([]);
  const [isScanning, setIsScanning] = useState(false);

  // Load saved server URL
  useEffect(() => {
    const loadSaved = async () => {
      if (window.electronAPI?.store) {
        const saved = await window.electronAPI.store.get('lastServerUrl');
        if (saved && typeof saved === 'string') {
          setServerUrl(saved);
        }
      }
    };
    loadSaved();
  }, []);

  const connectToServer = useCallback(async (url: string) => {
    setError('');
    setConnection({ url, status: 'connecting', offline: false });

    try {
      api.setBaseUrl(url);
      const info = await api.ping();
      setConnection({ url, status: 'connected', offline: false, info });

      // Save URL
      if (window.electronAPI?.store) {
        await window.electronAPI.store.set('lastServerUrl', url);
      }

      // Connect WebSocket for real-time updates
      api.connectWebSocket();

      setTimeout(onConnect, 500);
    } catch {
      setError('Could not connect to server. Check the URL and try again.');
      setConnection({ url, status: 'failed', offline: false });
    }
  }, [setConnection, onConnect]);

  const useOfflineMode = useCallback(() => {
    setConnection({ url: '', status: 'disconnected', offline: true });
    onConnect();
  }, [setConnection, onConnect]);

  const scanForServers = useCallback(async () => {
    setIsScanning(true);
    setTimeout(() => {
      setDiscoveredServers([]);
      setIsScanning(false);
    }, 2000);
  }, []);

  return (
    <motion.div
      className="fixed inset-0 bg-cinema-bg flex items-center justify-center"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.5 }}
    >
      {/* Background decoration */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <motion.div
          className="absolute top-1/4 left-1/4 w-96 h-96 bg-cinema-gold/5 rounded-full blur-3xl"
          animate={{ scale: [1, 1.1, 1], opacity: [0.5, 0.7, 0.5] }}
          transition={{ duration: 6, repeat: Infinity, ease: 'easeInOut' }}
        />
        <motion.div
          className="absolute bottom-1/4 right-1/4 w-72 h-72 bg-cinema-gold/3 rounded-full blur-3xl"
          animate={{ scale: [1, 1.15, 1], opacity: [0.3, 0.5, 0.3] }}
          transition={{ duration: 8, repeat: Infinity, ease: 'easeInOut' }}
        />
      </div>

      <motion.div
        className="relative w-[480px] glass rounded-2xl p-8"
        initial={{ opacity: 0, y: 30, scale: 0.95 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ delay: 0.2, duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
      >
        {/* Header */}
        <div className="text-center mb-8">
          <motion.h1
            className="text-3xl font-bold text-gold-gradient mb-2"
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4, duration: 0.4 }}
          >
            Connect to Server
          </motion.h1>
          <motion.p
            className="text-cinema-text-secondary text-sm"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.5, duration: 0.4 }}
          >
            Connect to a Cinemate server or use offline mode
          </motion.p>
        </div>

        {/* Server URL input */}
        <div className="mb-6">
          <label className="block text-cinema-text-secondary text-xs font-medium mb-2 uppercase tracking-wider">
            Server URL
          </label>
          <div className="flex gap-2">
            <input
              type="text"
              value={serverUrl}
              onChange={(e) => setServerUrl(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && connectToServer(serverUrl)}
              placeholder="http://localhost:9876"
              className="flex-1 bg-cinema-bg/60 border border-cinema-border rounded-lg px-4 py-3 text-white text-sm
                         focus:outline-none focus:border-cinema-gold/50 focus:ring-1 focus:ring-cinema-gold/20
                         focus:bg-cinema-bg/80
                         transition-all duration-250 placeholder-cinema-text-dim"
            />
            <motion.button
              onClick={() => connectToServer(serverUrl)}
              disabled={connection.status === 'connecting'}
              className="px-6 py-3 bg-cinema-gold hover:bg-cinema-gold-hover text-black font-semibold rounded-lg
                         transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed
                         hover:shadow-lg hover:shadow-cinema-gold/25 active:scale-[0.97]"
              whileTap={{ scale: 0.97 }}
            >
              {connection.status === 'connecting' ? (
                <span className="flex items-center gap-2">
                  <svg className="animate-spin w-4 h-4" viewBox="0 0 24 24" fill="none">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  ...
                </span>
              ) : (
                'Connect'
              )}
            </motion.button>
          </div>

          {/* Connection status */}
          <AnimatePresence mode="wait">
            {connection.status === 'connected' && (
              <motion.p
                key="connected"
                className="mt-3 text-cinema-green text-xs flex items-center gap-2"
                initial={{ opacity: 0, y: -5 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -5 }}
                transition={{ duration: 0.2 }}
              >
                <PulsingDot color="bg-cinema-green" />
                Connected to {connection.info?.server_name || 'server'}
              </motion.p>
            )}
            {error && (
              <motion.p
                key="error"
                className="mt-3 text-cinema-red text-xs flex items-center gap-2"
                initial={{ opacity: 0, y: -5 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -5 }}
                transition={{ duration: 0.2 }}
              >
                <svg className="w-3.5 h-3.5 shrink-0" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                </svg>
                {error}
              </motion.p>
            )}
          </AnimatePresence>
        </div>

        {/* Discover servers */}
        <div className="mb-6">
          <motion.button
            onClick={scanForServers}
            disabled={isScanning}
            className="w-full py-3 border border-cinema-border rounded-lg text-cinema-text-secondary text-sm
                       hover:border-cinema-gold/30 hover:text-white hover:bg-cinema-gold/5 transition-all duration-250
                       flex items-center justify-center gap-2 active:scale-[0.99]"
            whileTap={{ scale: 0.99 }}
          >
            {isScanning ? (
              <>
                <svg className="animate-spin w-4 h-4" viewBox="0 0 24 24" fill="none">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
                Scanning for servers...
              </>
            ) : (
              <>
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                    d="M8.111 16.404a5.5 5.5 0 017.778 0M12 20h.01m-7.08-7.071c3.904-3.905 10.236-3.905 14.141 0M1.394 9.393c5.857-5.858 15.355-5.858 21.213 0" />
                </svg>
                Discover Servers on Network
              </>
            )}
          </motion.button>

          {/* Discovered servers list */}
          <AnimatePresence>
            {discoveredServers.length > 0 && (
              <motion.div
                className="mt-3 space-y-2"
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                exit={{ opacity: 0, height: 0 }}
              >
                {discoveredServers.map((server, i) => (
                  <motion.button
                    key={i}
                    initial={{ opacity: 0, x: -10 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: i * 0.05 }}
                    onClick={() => connectToServer(server.url)}
                    className="w-full py-3 px-4 bg-cinema-surface rounded-lg text-left
                               hover:bg-cinema-gold/10 transition-all duration-200 group
                               border border-transparent hover:border-cinema-gold/20"
                  >
                    <div className="text-white text-sm font-medium group-hover:text-cinema-gold transition-colors">
                      {server.name}
                    </div>
                    <div className="text-cinema-text-dim text-xs font-mono mt-0.5">{server.url}</div>
                  </motion.button>
                ))}
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        {/* Divider */}
        <div className="flex items-center gap-4 mb-6">
          <div className="flex-1 h-px bg-gradient-to-r from-transparent via-cinema-border to-transparent" />
          <span className="text-cinema-text-dim text-xs uppercase tracking-wider">or</span>
          <div className="flex-1 h-px bg-gradient-to-r from-transparent via-cinema-border to-transparent" />
        </div>

        {/* Offline mode */}
        <motion.button
          onClick={useOfflineMode}
          className="w-full py-3.5 bg-cinema-surface hover:bg-cinema-card rounded-lg text-white text-sm font-medium
                     transition-all duration-200 border border-cinema-border hover:border-cinema-gold/20
                     active:scale-[0.99]"
          whileTap={{ scale: 0.99 }}
        >
          Use Offline Mode
          <span className="block text-cinema-text-dim text-xs mt-1">
            Browse your local library without a server
          </span>
        </motion.button>
      </motion.div>
    </motion.div>
  );
}
