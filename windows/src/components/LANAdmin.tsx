import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useServer } from '../hooks/useServer';
import { api } from '../api/client';
import type { ConnectedClient } from '../api/types';

function formatUptime(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

function StatusDot({ online }: { online: boolean }) {
  return (
    <span className="relative flex h-2.5 w-2.5">
      {online && (
        <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-cinema-green opacity-75" />
      )}
      <span className={`relative inline-flex rounded-full h-2.5 w-2.5 ${online ? 'bg-cinema-green' : 'bg-cinema-red'}`} />
    </span>
  );
}

const cardVariants = {
  hidden: { opacity: 0, y: 15 },
  visible: (i: number) => ({
    opacity: 1,
    y: 0,
    transition: { delay: i * 0.08, duration: 0.35, ease: [0.4, 0, 0.2, 1] },
  }),
};

export default function LANAdmin() {
  const { connection, isOnline } = useServer();
  const [clients, setClients] = useState<ConnectedClient[]>([]);
  const [loading, setLoading] = useState(false);
  const [accessMode, setAccessMode] = useState<'all' | 'specific' | 'pin'>('all');

  useEffect(() => {
    if (isOnline) {
      loadClients();
      const interval = setInterval(loadClients, 5000);
      return () => clearInterval(interval);
    }
  }, [isOnline]);

  const loadClients = async () => {
    try {
      setLoading(true);
      const data = await api.getConnectedClients();
      setClients(data);
    } catch {
      setClients([]);
    }
    setLoading(false);
  };

  const kickClient = async (clientId: string) => {
    try {
      await api.kickClient(clientId);
      await loadClients();
    } catch {}
  };

  return (
    <div className="h-full overflow-y-auto p-6">
      <motion.h2
        className="text-white text-xl font-semibold mb-6"
        initial={{ opacity: 0, x: -10 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.3 }}
      >
        LAN Administration
      </motion.h2>

      {/* Connection status */}
      <motion.div
        className="bg-cinema-surface rounded-xl p-5 border border-cinema-border mb-6"
        variants={cardVariants}
        initial="hidden"
        animate="visible"
        custom={0}
      >
        <h3 className="text-white text-sm font-semibold mb-4">Server Status</h3>
        <div className="grid grid-cols-3 gap-4">
          <div>
            <div className="text-cinema-text-dim text-xs mb-1.5 uppercase tracking-wider font-medium">Status</div>
            <div className="flex items-center gap-2">
              <StatusDot online={isOnline} />
              <span className={`text-sm font-medium ${isOnline ? 'text-cinema-green' : 'text-cinema-red'}`}>
                {isOnline ? 'Connected' : 'Offline'}
              </span>
            </div>
          </div>
          <div>
            <div className="text-cinema-text-dim text-xs mb-1.5 uppercase tracking-wider font-medium">Server Name</div>
            <div className="text-white text-sm font-medium">
              {connection.info?.server_name || 'N/A'}
            </div>
          </div>
          <div>
            <div className="text-cinema-text-dim text-xs mb-1.5 uppercase tracking-wider font-medium">Server URL</div>
            <div className="text-white text-sm font-medium font-mono tabular-nums">
              {connection.url || 'N/A'}
            </div>
          </div>
        </div>
      </motion.div>

      {/* Connected clients */}
      <motion.div
        className="bg-cinema-surface rounded-xl p-5 border border-cinema-border mb-6"
        variants={cardVariants}
        initial="hidden"
        animate="visible"
        custom={1}
      >
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-white text-sm font-semibold">
            Connected Clients
            <span className="ml-2 px-2 py-0.5 text-[10px] font-bold rounded-full bg-cinema-gold/15 text-cinema-gold">
              {clients.length}
            </span>
          </h3>
          <motion.button
            onClick={loadClients}
            disabled={!isOnline || loading}
            className="text-cinema-text-secondary hover:text-cinema-gold text-xs transition-colors duration-200 disabled:opacity-50
                       flex items-center gap-1.5"
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
          >
            <svg className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            Refresh
          </motion.button>
        </div>

        {!isOnline ? (
          <div className="text-center py-10 text-cinema-text-dim text-sm">
            <svg className="w-10 h-10 mx-auto mb-3 opacity-20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M18.364 5.636a9 9 0 010 12.728m0 0l-2.829-2.829m2.829 2.829L21 21M15.536 8.464a5 5 0 010 7.072m0 0l-2.829-2.829m-4.243 2.829a4.978 4.978 0 01-1.414-2.83m-1.414 5.658a9 9 0 01-2.167-9.238m7.824 2.167a1 1 0 111.414 1.414m-1.414-1.414L3 3" />
            </svg>
            Connect to a server to manage clients
          </div>
        ) : clients.length === 0 ? (
          <div className="text-center py-10 text-cinema-text-dim text-sm">
            <svg className="w-10 h-10 mx-auto mb-3 opacity-20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
            </svg>
            No clients connected
          </div>
        ) : (
          <div className="space-y-2">
            <AnimatePresence>
              {clients.map((client, i) => (
                <motion.div
                  key={client.id}
                  className="flex items-center gap-4 p-3 bg-cinema-bg/50 rounded-lg
                             hover:bg-cinema-bg/70 transition-colors duration-150
                             border border-transparent hover:border-cinema-border/50"
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, x: -20 }}
                  transition={{ delay: i * 0.04, duration: 0.2 }}
                >
                  {/* Device icon */}
                  <div className="w-9 h-9 rounded-lg bg-cinema-gold/10 flex items-center justify-center">
                    <svg className="w-4.5 h-4.5 text-cinema-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                    </svg>
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="text-white text-sm font-medium">{client.client_name}</span>
                      <span className="text-cinema-text-dim text-xs font-mono tabular-nums">{client.client_ip}</span>
                    </div>
                    <div className="flex items-center gap-3 mt-0.5">
                      {client.watching_title && (
                        <span className="text-cinema-gold text-xs flex items-center gap-1">
                          <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
                            <path d="M8 5v14l11-7z" />
                          </svg>
                          {client.watching_title}
                        </span>
                      )}
                      <span className="text-cinema-text-dim text-xs tabular-nums">
                        Connected: {client.connected_at || 'N/A'}
                      </span>
                    </div>
                  </div>

                  <motion.button
                    onClick={() => kickClient(client.id)}
                    className="px-3 py-1.5 text-cinema-red text-xs font-medium rounded-lg
                               bg-cinema-red/10 hover:bg-cinema-red/20 transition-all duration-200
                               border border-cinema-red/10 hover:border-cinema-red/30"
                    whileHover={{ scale: 1.03 }}
                    whileTap={{ scale: 0.97 }}
                  >
                    Kick
                  </motion.button>
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        )}
      </motion.div>

      {/* Access control */}
      <motion.div
        className="bg-cinema-surface rounded-xl p-5 border border-cinema-border"
        variants={cardVariants}
        initial="hidden"
        animate="visible"
        custom={2}
      >
        <h3 className="text-white text-sm font-semibold mb-4">Access Control</h3>
        <div className="space-y-2">
          {(['all', 'specific', 'pin'] as const).map((mode, i) => (
            <motion.label
              key={mode}
              className={`flex items-center gap-3 p-3.5 rounded-lg cursor-pointer transition-all duration-200
                          ${accessMode === mode
                            ? 'bg-cinema-gold/10 border border-cinema-gold/25'
                            : 'hover:bg-cinema-bg/50 border border-transparent hover:border-cinema-border/50'
                          }`}
              whileHover={{ x: 2 }}
              whileTap={{ scale: 0.995 }}
            >
              <input
                type="radio"
                name="accessMode"
                checked={accessMode === mode}
                onChange={() => setAccessMode(mode)}
                className="hidden"
              />
              <div className={`w-[18px] h-[18px] rounded-full border-2 flex items-center justify-center transition-all duration-200
                              ${accessMode === mode ? 'border-cinema-gold' : 'border-cinema-text-dim hover:border-cinema-text-secondary'}`}>
                <motion.div
                  className="rounded-full bg-cinema-gold"
                  initial={false}
                  animate={{ scale: accessMode === mode ? 1 : 0, width: 8, height: 8 }}
                  transition={{ type: 'spring', stiffness: 500, damping: 30 }}
                />
              </div>
              <div>
                <span className={`text-sm font-medium transition-colors duration-200
                                 ${accessMode === mode ? 'text-cinema-gold' : 'text-white'}`}>
                  {mode === 'all' && 'Allow All'}
                  {mode === 'specific' && 'Specific IPs Only'}
                  {mode === 'pin' && 'Require PIN'}
                </span>
                <p className="text-cinema-text-dim text-xs mt-0.5">
                  {mode === 'all' && 'Any device on the network can connect'}
                  {mode === 'specific' && 'Only whitelisted IP addresses can connect'}
                  {mode === 'pin' && 'Clients must enter a PIN to access the library'}
                </p>
              </div>
            </motion.label>
          ))}
        </div>
      </motion.div>
    </div>
  );
}
