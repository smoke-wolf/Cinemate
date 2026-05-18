import React, { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useServer } from '../hooks/useServer';
import { api } from '../api/client';
import type { ConnectedClient } from '../api/types';

// ─── Helpers ───

function deviceIcon(clientName: string) {
  const name = clientName.toLowerCase();
  if (name.includes('iphone') || name.includes('android') || name.includes('phone') || name.includes('mobile')) {
    return (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
      </svg>
    );
  }
  if (name.includes('ipad') || name.includes('tablet')) {
    return (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 18h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
      </svg>
    );
  }
  if (name.includes('tv') || name.includes('apple tv') || name.includes('roku') || name.includes('firestick') || name.includes('chromecast')) {
    return (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
      </svg>
    );
  }
  // Default: laptop/desktop
  return (
    <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
    </svg>
  );
}

function formatConnectedTime(dateStr: string): string {
  try {
    const connected = new Date(dateStr);
    const diff = Date.now() - connected.getTime();
    const minutes = Math.floor(diff / 60000);
    if (minutes < 1) return 'just now';
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    return `${days}d ago`;
  } catch {
    return dateStr || 'N/A';
  }
}

// Teal accent to match macOS DevicesView
const ACCENT_TEAL = '#33bfb3';

const cardVariants = {
  hidden: { opacity: 0, y: 15 },
  visible: (i: number) => ({
    opacity: 1,
    y: 0,
    transition: { delay: i * 0.06, duration: 0.35, ease: [0.4, 0, 0.2, 1] },
  }),
};

export default function DevicesView() {
  const { connection, isOnline } = useServer();
  const [clients, setClients] = useState<ConnectedClient[]>([]);
  const [loading, setLoading] = useState(false);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const loadClients = useCallback(async () => {
    if (!isOnline) return;
    try {
      setLoading(true);
      const data = await api.getConnectedClients();
      setClients(data);
    } catch {
      setClients([]);
    }
    setLoading(false);
  }, [isOnline]);

  useEffect(() => {
    if (isOnline) {
      loadClients();
      const interval = setInterval(loadClients, 5000);
      return () => clearInterval(interval);
    }
  }, [isOnline, loadClients]);

  const kickClient = async (clientId: string) => {
    try {
      await api.kickClient(clientId);
      await loadClients();
    } catch {}
  };

  const onlineClients = clients; // All connected clients are online by definition
  const serverUrl = connection.url;

  return (
    <div className="h-full overflow-y-auto p-6">
      {/* Header */}
      <motion.div
        className="flex items-center gap-4 mb-6"
        initial={{ opacity: 0, x: -20 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.4 }}
      >
        <div
          className="w-12 h-12 rounded-xl flex items-center justify-center"
          style={{ background: `linear-gradient(135deg, ${ACCENT_TEAL}33, ${ACCENT_TEAL}0d)` }}
        >
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke={ACCENT_TEAL}>
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
          </svg>
        </div>
        <div>
          <h2 className="text-white text-2xl font-bold">Devices</h2>
          <p className="text-cinema-text-dim text-sm">
            {onlineClients.length} online
          </p>
        </div>
        <div className="flex-1" />
        <motion.button
          onClick={loadClients}
          disabled={!isOnline || loading}
          className="flex items-center gap-1.5 px-3.5 py-2 text-xs font-medium text-cinema-text-secondary
                     bg-white/[0.06] hover:bg-white/[0.1] rounded-lg transition-colors duration-200
                     disabled:opacity-50"
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
        >
          <svg className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          Refresh
        </motion.button>
      </motion.div>

      {/* Empty state */}
      {!isOnline ? (
        <motion.div
          className="flex flex-col items-center justify-center py-24 text-center"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2, duration: 0.4 }}
        >
          <svg className="w-16 h-16 mb-4 text-white/[0.08]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M18.364 5.636a9 9 0 010 12.728m0 0l-2.829-2.829m2.829 2.829L21 21M15.536 8.464a5 5 0 010 7.072m0 0l-2.829-2.829m-4.243 2.829a4.978 4.978 0 01-1.414-2.83m-1.414 5.658a9 9 0 01-2.167-9.238m7.824 2.167a1 1 0 111.414 1.414m-1.414-1.414L3 3" />
          </svg>
          <p className="text-white/30 text-lg font-semibold mb-1">No Server Connected</p>
          <p className="text-white/[0.15] text-sm max-w-xs">
            Connect to a Cinemate server to see other devices on your network.
          </p>
        </motion.div>
      ) : clients.length === 0 ? (
        <motion.div
          className="flex flex-col items-center justify-center py-24 text-center"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2, duration: 0.4 }}
        >
          <svg className="w-16 h-16 mb-4 text-white/[0.08]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
          </svg>
          <p className="text-white/30 text-lg font-semibold mb-1">No Devices Found</p>
          <p className="text-white/[0.15] text-sm max-w-xs">
            No devices are connected to your Cinemate server.
            Open Cinemate on another device to get started.
          </p>
        </motion.div>
      ) : (
        <>
          {/* Server URL card */}
          {serverUrl && (
            <motion.div
              className="bg-cinema-surface rounded-xl p-4 border border-cinema-border mb-6 flex items-center gap-3"
              variants={cardVariants}
              initial="hidden"
              animate="visible"
              custom={0}
            >
              <div
                className="w-10 h-10 rounded-lg flex items-center justify-center"
                style={{ backgroundColor: `${ACCENT_TEAL}1a` }}
              >
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke={ACCENT_TEAL}>
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                </svg>
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-cinema-text-dim text-[10px] uppercase tracking-wider font-medium">Server URL</div>
                <div className="text-white text-sm font-mono tabular-nums truncate">{serverUrl}</div>
              </div>
            </motion.div>
          )}

          {/* Online devices header */}
          <motion.div
            className="flex items-center justify-between mb-3"
            variants={cardVariants}
            initial="hidden"
            animate="visible"
            custom={1}
          >
            <h3 className="text-white text-sm font-semibold">Online</h3>
            <span
              className="px-2.5 py-1 text-[11px] font-medium rounded-full"
              style={{ backgroundColor: `${ACCENT_TEAL}1a`, color: ACCENT_TEAL }}
            >
              {onlineClients.length}
            </span>
          </motion.div>

          {/* Device grid */}
          <div className="grid grid-cols-2 gap-3">
            <AnimatePresence>
              {onlineClients.map((client, i) => {
                const isExpanded = expandedId === client.id;
                return (
                  <motion.div
                    key={client.id}
                    className="bg-cinema-surface rounded-xl border transition-colors duration-200 cursor-pointer"
                    style={{
                      borderColor: `${ACCENT_TEAL}26`,
                    }}
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, scale: 0.95 }}
                    transition={{ delay: i * 0.06, duration: 0.3, ease: [0.4, 0, 0.2, 1] }}
                    onClick={() => setExpandedId(isExpanded ? null : client.id)}
                    whileHover={{ scale: 1.01 }}
                  >
                    <div className="p-4">
                      <div className="flex items-center gap-3">
                        {/* Device icon */}
                        <div
                          className="w-11 h-11 rounded-[10px] flex items-center justify-center shrink-0"
                          style={{ backgroundColor: `${ACCENT_TEAL}1a`, color: ACCENT_TEAL }}
                        >
                          {deviceIcon(client.client_name)}
                        </div>

                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-1.5">
                            <span className="text-white text-sm font-semibold truncate">{client.client_name}</span>
                            <span className="relative flex h-2 w-2 shrink-0">
                              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-cinema-green opacity-75" />
                              <span className="relative inline-flex rounded-full h-2 w-2 bg-cinema-green" />
                            </span>
                          </div>
                          <span className="text-cinema-text-dim text-xs font-mono tabular-nums">{client.client_ip}</span>
                        </div>

                        <svg
                          className={`w-3.5 h-3.5 text-cinema-text-dim transition-transform duration-200 ${isExpanded ? 'rotate-180' : ''}`}
                          fill="none" viewBox="0 0 24 24" stroke="currentColor"
                        >
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                        </svg>
                      </div>

                      {/* Activity */}
                      {client.watching_title && (
                        <div className="mt-2.5 flex items-center gap-1.5">
                          <svg className="w-3 h-3 text-cinema-gold shrink-0" fill="currentColor" viewBox="0 0 24 24">
                            <path d="M8 5v14l11-7z" />
                          </svg>
                          <span className="text-cinema-gold text-xs truncate">{client.watching_title}</span>
                        </div>
                      )}

                      {/* Expanded details */}
                      <AnimatePresence>
                        {isExpanded && (
                          <motion.div
                            initial={{ height: 0, opacity: 0 }}
                            animate={{ height: 'auto', opacity: 1 }}
                            exit={{ height: 0, opacity: 0 }}
                            transition={{ duration: 0.2, ease: [0.4, 0, 0.2, 1] }}
                            className="overflow-hidden"
                          >
                            <div className="mt-3 pt-3 border-t border-cinema-border/50 space-y-2">
                              {/* Info rows */}
                              <div className="flex items-center gap-2">
                                <svg className="w-3 h-3 text-cinema-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                                </svg>
                                <span className="text-cinema-text-dim text-xs">Connected</span>
                                <span className="text-white/80 text-xs font-medium ml-auto tabular-nums">
                                  {formatConnectedTime(client.connected_at)}
                                </span>
                              </div>

                              <div className="flex items-center gap-2">
                                <svg className="w-3 h-3 text-cinema-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.111 16.404a5.5 5.5 0 017.778 0M12 20h.01m-7.08-7.071c3.904-3.905 10.236-3.905 14.14 0M1.394 9.393c5.857-5.858 15.355-5.858 21.213 0" />
                                </svg>
                                <span className="text-cinema-text-dim text-xs">Status</span>
                                <span className="text-white/80 text-xs font-medium ml-auto" style={{ color: ACCENT_TEAL }}>
                                  Connected
                                </span>
                              </div>

                              {client.account_name && (
                                <div className="flex items-center gap-2">
                                  <svg className="w-3 h-3 text-cinema-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                                  </svg>
                                  <span className="text-cinema-text-dim text-xs">Account</span>
                                  <span className="text-white/80 text-xs font-medium ml-auto">{client.account_name}</span>
                                </div>
                              )}

                              {/* Kick button */}
                              <div className="pt-2">
                                <motion.button
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    kickClient(client.id);
                                  }}
                                  className="px-3 py-1.5 text-cinema-red text-xs font-medium rounded-lg
                                             bg-cinema-red/10 hover:bg-cinema-red/20 transition-all duration-200
                                             border border-cinema-red/10 hover:border-cinema-red/30"
                                  whileHover={{ scale: 1.03 }}
                                  whileTap={{ scale: 0.97 }}
                                >
                                  Disconnect
                                </motion.button>
                              </div>
                            </div>
                          </motion.div>
                        )}
                      </AnimatePresence>
                    </div>
                  </motion.div>
                );
              })}
            </AnimatePresence>
          </div>
        </>
      )}
    </div>
  );
}
