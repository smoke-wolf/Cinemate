import React, { useState, useEffect, useCallback } from 'react';
import { motion } from 'framer-motion';
import { useServer } from '../hooks/useServer';
import { useAccounts } from '../hooks/useAccounts';
import { useLibrary } from '../hooks/useLibrary';
import { api } from '../api/client';

// ---- Constants ----

const VIDEO_QUALITIES = ['Auto', '4K', '1080p', '720p', '480p'];
const SUBTITLE_LANGUAGES = ['Off', 'English', 'Spanish', 'French', 'German', 'Japanese', 'Korean', 'Chinese', 'Portuguese', 'Italian'];
const SUBTITLE_SIZES = ['Small', 'Medium', 'Large', 'Extra Large'];

// ---- Animation variants ----

const cardVariants = {
  hidden: { opacity: 0, y: 15 },
  visible: (i: number) => ({
    opacity: 1,
    y: 0,
    transition: { delay: i * 0.08, duration: 0.35, ease: [0.4, 0, 0.2, 1] },
  }),
};

// ---- Helpers ----

function formatBytes(bytes: number): string {
  if (bytes > 1_073_741_824) return `${(bytes / 1_073_741_824).toFixed(1)} GB`;
  if (bytes > 1_048_576) return `${(bytes / 1_048_576).toFixed(1)} MB`;
  if (bytes > 1024) return `${Math.round(bytes / 1024)} KB`;
  return '0 KB';
}

function StatusDot({ color }: { color: 'green' | 'orange' | 'gray' }) {
  const colorMap = {
    green: 'bg-cinema-green',
    orange: 'bg-orange-400',
    gray: 'bg-gray-500',
  };
  return <span className={`inline-block w-2 h-2 rounded-full ${colorMap[color]}`} />;
}

// ---- Toggle component ----

function Toggle({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent
                  transition-colors duration-200 ease-in-out focus:outline-none
                  ${checked ? 'bg-cinema-gold' : 'bg-white/10'}`}
    >
      <span
        className={`pointer-events-none inline-block h-5 w-5 rounded-full bg-white shadow-lg
                    transform transition duration-200 ease-in-out
                    ${checked ? 'translate-x-5' : 'translate-x-0'}`}
      />
    </button>
  );
}

// ---- Main Component ----

export default function SettingsView() {
  const { connection, isOnline } = useServer();
  const { currentAccount } = useAccounts();
  const { movies, tvShows, musicTrackCount, setActiveTab, scanFolder } = useLibrary();

  // -- Server connection state --
  const [serverPing, setServerPing] = useState('--');
  const [serverName, setServerName] = useState('--');
  const [serverVersion, setServerVersion] = useState('--');
  const [isServerReachable, setIsServerReachable] = useState(false);
  const [isTesting, setIsTesting] = useState(false);

  // -- Library state --
  const [scanDirectories, setScanDirectories] = useState<string[]>([]);
  const [lastScanTime, setLastScanTime] = useState('Never');
  const [autoScanOnStartup, setAutoScanOnStartup] = useState(true);
  const [isScanning, setIsScanning] = useState(false);

  // -- Playback state --
  const [defaultVideoQuality, setDefaultVideoQuality] = useState('Auto');
  const [autoPlayNextEpisode, setAutoPlayNextEpisode] = useState(true);
  const [rememberPlaybackPosition, setRememberPlaybackPosition] = useState(true);
  const [subtitleLanguage, setSubtitleLanguage] = useState('English');
  const [subtitleSize, setSubtitleSize] = useState('Medium');

  // -- Music state --
  const [gaplessPlayback, setGaplessPlayback] = useState(true);
  const [audioNormalization, setAudioNormalization] = useState(false);
  const [crossfadeDuration, setCrossfadeDuration] = useState(0);

  // -- Cache state --
  const [imageCacheSize, setImageCacheSize] = useState('Calculating...');
  const [artistCacheSize, setArtistCacheSize] = useState('Calculating...');
  const [databaseSize, setDatabaseSize] = useState('Calculating...');
  const [totalStorageUsed, setTotalStorageUsed] = useState('Calculating...');
  const [showClearAllConfirm, setShowClearAllConfirm] = useState(false);
  const [isClearingCache, setIsClearingCache] = useState(false);

  // -- Network state --
  const [mDNSDiscovery, setMDNSDiscovery] = useState(true);
  const [defaultServerPort, setDefaultServerPort] = useState('9876');

  // -- Load initial state --
  useEffect(() => {
    pingServer();
    fetchServerInfo();
    loadSettings();
    estimateCacheSizes();
  }, []);

  const pingServer = useCallback(async () => {
    if (!connection.url) {
      setServerPing('N/A');
      setIsServerReachable(false);
      return;
    }
    const start = Date.now();
    try {
      await api.ping();
      const ms = Date.now() - start;
      setServerPing(`${ms}ms`);
      setIsServerReachable(true);
    } catch {
      setServerPing('Unreachable');
      setIsServerReachable(false);
    }
  }, [connection.url]);

  const fetchServerInfo = useCallback(async () => {
    if (!connection.url) {
      setServerName('Not connected');
      setServerVersion('--');
      return;
    }
    try {
      const info = await api.ping();
      setServerName(info.server_name || 'Cinemate Server');
      setServerVersion(info.version || 'Unknown');
    } catch {
      setServerName('Cinemate Server');
      setServerVersion('Unknown');
    }
  }, [connection.url]);

  const testConnection = async () => {
    setIsTesting(true);
    const start = Date.now();
    try {
      const info = await api.ping();
      const ms = Date.now() - start;
      setServerPing(`${ms}ms`);
      setIsServerReachable(true);
      setServerName(info.server_name || 'Cinemate Server');
      setServerVersion(info.version || 'Unknown');
    } catch {
      setServerPing('Unreachable');
      setIsServerReachable(false);
    }
    setIsTesting(false);
  };

  const loadSettings = () => {
    // Load from localStorage
    const dirs = localStorage.getItem('cinemate.scanDirectories');
    if (dirs) {
      try { setScanDirectories(JSON.parse(dirs)); } catch {}
    }
    const lastScan = localStorage.getItem('cinemate.lastScanTime');
    if (lastScan) {
      const d = new Date(lastScan);
      const now = new Date();
      const diff = now.getTime() - d.getTime();
      const mins = Math.floor(diff / 60000);
      const hours = Math.floor(mins / 60);
      const days = Math.floor(hours / 24);
      if (days > 0) setLastScanTime(`${days} day${days > 1 ? 's' : ''} ago`);
      else if (hours > 0) setLastScanTime(`${hours} hour${hours > 1 ? 's' : ''} ago`);
      else if (mins > 0) setLastScanTime(`${mins} minute${mins > 1 ? 's' : ''} ago`);
      else setLastScanTime('Just now');
    }
    const autoScan = localStorage.getItem('cinemate.autoScanOnStartup');
    if (autoScan !== null) setAutoScanOnStartup(autoScan === 'true');
    const quality = localStorage.getItem('cinemate.defaultVideoQuality');
    if (quality) setDefaultVideoQuality(quality);
    const autoPlay = localStorage.getItem('cinemate.autoPlayNextEpisode');
    if (autoPlay !== null) setAutoPlayNextEpisode(autoPlay === 'true');
    const remember = localStorage.getItem('cinemate.rememberPlaybackPosition');
    if (remember !== null) setRememberPlaybackPosition(remember === 'true');
    const subLang = localStorage.getItem('cinemate.subtitleLanguage');
    if (subLang) setSubtitleLanguage(subLang);
    const subSize = localStorage.getItem('cinemate.subtitleSize');
    if (subSize) setSubtitleSize(subSize);
    const gapless = localStorage.getItem('cinemate.gaplessPlayback');
    if (gapless !== null) setGaplessPlayback(gapless === 'true');
    const normalization = localStorage.getItem('cinemate.audioNormalization');
    if (normalization !== null) setAudioNormalization(normalization === 'true');
    const crossfade = localStorage.getItem('cinemate.crossfadeDuration');
    if (crossfade !== null) setCrossfadeDuration(parseFloat(crossfade));
    const mdns = localStorage.getItem('cinemate.mDNSDiscovery');
    if (mdns !== null) setMDNSDiscovery(mdns === 'true');
    const port = localStorage.getItem('cinemate.defaultServerPort');
    if (port) setDefaultServerPort(port);
  };

  const estimateCacheSizes = () => {
    // In Electron, we'd use fs to calculate actual sizes.
    // For now, estimate from localStorage and provide reasonable defaults.
    try {
      let totalLocal = 0;
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key) {
          totalLocal += (localStorage.getItem(key) || '').length * 2;
        }
      }
      setImageCacheSize(formatBytes(totalLocal > 0 ? totalLocal * 10 : 0));
      setArtistCacheSize(formatBytes(0));
      setDatabaseSize(formatBytes(totalLocal));
      setTotalStorageUsed(formatBytes(totalLocal * 11) + ' total');
    } catch {
      setImageCacheSize('0 KB');
      setArtistCacheSize('0 KB');
      setDatabaseSize('0 KB');
      setTotalStorageUsed('0 KB total');
    }
  };

  // Persist settings helpers
  const saveSetting = (key: string, value: string) => {
    localStorage.setItem(`cinemate.${key}`, value);
  };

  const handleAddDirectory = async () => {
    if (!window.electronAPI?.selectDirectory) return;
    const dir = await window.electronAPI.selectDirectory();
    if (dir && !scanDirectories.includes(dir)) {
      const updated = [...scanDirectories, dir];
      setScanDirectories(updated);
      localStorage.setItem('cinemate.scanDirectories', JSON.stringify(updated));
    }
  };

  const handleRemoveDirectory = (dir: string) => {
    const updated = scanDirectories.filter((d) => d !== dir);
    setScanDirectories(updated);
    localStorage.setItem('cinemate.scanDirectories', JSON.stringify(updated));
  };

  const handleRescanLibrary = async () => {
    setIsScanning(true);
    for (const dir of scanDirectories) {
      try {
        await api.scanFolder(dir);
      } catch {}
    }
    localStorage.setItem('cinemate.lastScanTime', new Date().toISOString());
    setLastScanTime('Just now');
    setIsScanning(false);
  };

  const handleClearAllCaches = () => {
    setIsClearingCache(true);
    // Clear relevant localStorage entries
    const keysToKeep = ['cinemate.scanDirectories', 'cinemate.lastScanTime', 'cinemate.autoScanOnStartup'];
    const keysToRemove: string[] = [];
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (key && key.startsWith('cinemate.cache.') && !keysToKeep.includes(key)) {
        keysToRemove.push(key);
      }
    }
    keysToRemove.forEach((k) => localStorage.removeItem(k));
    setTimeout(() => {
      setIsClearingCache(false);
      setShowClearAllConfirm(false);
      estimateCacheSizes();
    }, 500);
  };

  // Connection status color
  const connColor = isServerReachable ? 'green' : (connection.url ? 'orange' : 'gray') as const;
  const connLabel = isServerReachable ? 'Connected' : (connection.url ? 'Unreachable' : 'Disconnected');

  return (
    <div className="h-full overflow-y-auto">
      <div className="p-8 max-w-4xl space-y-6">
        {/* Header */}
        <motion.div
          className="flex items-center gap-3.5"
          initial={{ opacity: 0, x: -10 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.3 }}
        >
          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-cinema-gold/20 to-cinema-gold/5 flex items-center justify-center">
            <svg className="w-6 h-6 text-cinema-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          </div>
          <div>
            <h2 className="text-white text-2xl font-bold">Settings</h2>
            <p className="text-cinema-text-secondary text-sm">Configure your Cinemate experience</p>
          </div>
        </motion.div>

        {/* ===== SERVER CONNECTION CARD ===== */}
        <motion.div
          className="bg-cinema-surface rounded-xl border border-cinema-border"
          variants={cardVariants} initial="hidden" animate="visible" custom={0}
        >
          <div className="p-5">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-white text-sm font-semibold">Server Connection</h3>
              <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold
                              ${connColor === 'green' ? 'bg-cinema-green/10 text-cinema-green border border-cinema-green/20' :
                                connColor === 'orange' ? 'bg-orange-400/10 text-orange-400 border border-orange-400/20' :
                                'bg-gray-500/10 text-gray-500 border border-gray-500/20'}`}>
                <StatusDot color={connColor} />
                {connLabel}
              </div>
            </div>

            <div className="bg-cinema-bg/50 rounded-lg border border-white/[0.04] divide-y divide-white/[0.04]">
              {/* Server URL */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-cinema-text-dim text-[11px] font-medium uppercase tracking-wider">Server URL</div>
                  <div className="text-white text-sm font-mono mt-0.5">{connection.url || 'Not configured'}</div>
                </div>
                <div className="flex items-center gap-1.5">
                  <StatusDot color={isServerReachable ? 'green' : 'gray'} />
                  <span className={`text-xs font-mono ${isServerReachable ? 'text-cinema-green' : 'text-cinema-red'}`}>
                    {serverPing}
                  </span>
                </div>
              </div>

              {/* Server name & version */}
              <div className="flex gap-6 p-3.5">
                <div>
                  <div className="text-cinema-text-dim text-[11px] font-medium uppercase tracking-wider">Server Name</div>
                  <div className="text-white text-sm font-medium mt-0.5">{serverName}</div>
                </div>
                <div>
                  <div className="text-cinema-text-dim text-[11px] font-medium uppercase tracking-wider">Version</div>
                  <div className="text-white text-sm font-medium mt-0.5">{serverVersion}</div>
                </div>
              </div>

              {/* Library stats */}
              <div className="grid grid-cols-4 divide-x divide-white/[0.04]">
                {[
                  { icon: 'M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z', label: 'Movies', count: movies.length },
                  { icon: 'M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z', label: 'TV Shows', count: tvShows.length },
                  { icon: 'M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3', label: 'Tracks', count: musicTrackCount },
                  { icon: 'M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253', label: 'Books', count: 0 },
                ].map((stat) => (
                  <div key={stat.label} className="flex flex-col items-center py-3 gap-1">
                    <svg className="w-4 h-4 text-cinema-gold/70" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d={stat.icon} />
                    </svg>
                    <span className="text-white text-base font-bold tabular-nums">{stat.count}</span>
                    <span className="text-cinema-text-dim text-[10px] font-medium">{stat.label}</span>
                  </div>
                ))}
              </div>

              {/* Action buttons */}
              <div className="flex items-center gap-2.5 p-3.5">
                <motion.button
                  onClick={testConnection}
                  disabled={isTesting}
                  className="flex items-center gap-1.5 px-4 py-2 bg-cinema-gold text-black text-xs font-semibold rounded-lg
                             hover:bg-cinema-gold-hover transition-colors disabled:opacity-50"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                >
                  {isTesting ? (
                    <div className="w-3.5 h-3.5 border-2 border-black/30 border-t-black rounded-full animate-spin" />
                  ) : (
                    <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.111 16.404a5.5 5.5 0 017.778 0M12 20h.01m-7.08-7.071c3.904-3.905 10.236-3.905 14.141 0M1.394 9.393c5.857-5.858 15.355-5.858 21.213 0" />
                    </svg>
                  )}
                  {isTesting ? 'Testing...' : 'Test Connection'}
                </motion.button>
              </div>
            </div>
          </div>
        </motion.div>

        {/* ===== LIBRARY CARD ===== */}
        <motion.div
          className="bg-cinema-surface rounded-xl border border-cinema-border"
          variants={cardVariants} initial="hidden" animate="visible" custom={1}
        >
          <div className="p-5">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-white text-sm font-semibold">Library</h3>
              {isScanning && (
                <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-cinema-gold/10 text-cinema-gold text-xs font-medium">
                  <div className="w-3 h-3 border-2 border-cinema-gold/30 border-t-cinema-gold rounded-full animate-spin" />
                  Scanning...
                </div>
              )}
            </div>

            <div className="bg-cinema-bg/50 rounded-lg border border-white/[0.04] divide-y divide-white/[0.04]">
              {/* Media directories */}
              <div className="p-3.5">
                <div className="text-cinema-text-dim text-xs font-medium mb-2.5">Media Directories</div>
                {scanDirectories.length === 0 ? (
                  <div className="flex items-center gap-2 py-2 text-white/20 text-sm">
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
                    </svg>
                    No directories configured
                  </div>
                ) : (
                  <div className="space-y-1.5">
                    {scanDirectories.map((dir) => (
                      <div key={dir} className="flex items-center gap-2.5 px-2.5 py-1.5 bg-white/[0.03] rounded-md">
                        <svg className="w-3.5 h-3.5 text-cinema-gold/70 shrink-0" fill="currentColor" viewBox="0 0 20 20">
                          <path d="M2 6a2 2 0 012-2h5l2 2h5a2 2 0 012 2v6a2 2 0 01-2 2H4a2 2 0 01-2-2V6z" />
                        </svg>
                        <span className="text-white/80 text-xs font-mono flex-1 truncate">{dir}</span>
                        <button
                          onClick={() => handleRemoveDirectory(dir)}
                          className="text-cinema-red/50 hover:text-cinema-red transition-colors"
                        >
                          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                          </svg>
                        </button>
                      </div>
                    ))}
                  </div>
                )}
                <motion.button
                  onClick={handleAddDirectory}
                  className="flex items-center gap-1.5 mt-2.5 px-3.5 py-1.5 text-cinema-gold text-xs font-medium
                             bg-cinema-gold/10 rounded-md hover:bg-cinema-gold/15 transition-colors"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                >
                  <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                  </svg>
                  Add Directory
                </motion.button>
              </div>

              {/* Scan controls */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-cinema-text-dim text-[11px] font-medium uppercase tracking-wider">Last Scan</div>
                  <div className="text-white text-sm font-medium mt-0.5">{lastScanTime}</div>
                </div>
                <motion.button
                  onClick={handleRescanLibrary}
                  disabled={isScanning || scanDirectories.length === 0}
                  className="flex items-center gap-1.5 px-4 py-2 bg-cinema-gold text-black text-xs font-semibold rounded-lg
                             hover:bg-cinema-gold-hover transition-colors disabled:opacity-50"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                >
                  <svg className={`w-3.5 h-3.5 ${isScanning ? 'animate-spin' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                  Rescan Library
                </motion.button>
              </div>

              {/* Auto-scan toggle */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-white text-sm font-medium">Auto-Scan on Startup</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Automatically scan media directories when the app launches</div>
                </div>
                <Toggle
                  checked={autoScanOnStartup}
                  onChange={(v) => { setAutoScanOnStartup(v); saveSetting('autoScanOnStartup', String(v)); }}
                />
              </div>
            </div>
          </div>
        </motion.div>

        {/* ===== PLAYBACK CARD ===== */}
        <motion.div
          className="bg-cinema-surface rounded-xl border border-cinema-border"
          variants={cardVariants} initial="hidden" animate="visible" custom={2}
        >
          <div className="p-5">
            <h3 className="text-white text-sm font-semibold mb-4">Playback</h3>
            <div className="bg-cinema-bg/50 rounded-lg border border-white/[0.04] divide-y divide-white/[0.04]">
              {/* Default video quality */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-white text-sm font-medium">Default Video Quality</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Preferred quality when streaming from server</div>
                </div>
                <select
                  value={defaultVideoQuality}
                  onChange={(e) => { setDefaultVideoQuality(e.target.value); saveSetting('defaultVideoQuality', e.target.value); }}
                  className="bg-white/[0.06] border border-cinema-border rounded-md px-3 py-1.5 text-white text-xs
                             focus:outline-none focus:border-cinema-gold/50 cursor-pointer appearance-none pr-7"
                  style={{
                    backgroundImage: `url("data:image/svg+xml,%3Csvg width='10' height='6' viewBox='0 0 10 6' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M1 1L5 5L9 1' stroke='%236b7280' stroke-width='1.5' stroke-linecap='round'/%3E%3C/svg%3E")`,
                    backgroundRepeat: 'no-repeat',
                    backgroundPosition: 'right 8px center',
                  }}
                >
                  {VIDEO_QUALITIES.map((q) => (
                    <option key={q} value={q}>{q}</option>
                  ))}
                </select>
              </div>

              {/* Auto-play next episode */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-white text-sm font-medium">Auto-Play Next Episode</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Automatically play the next episode in a series</div>
                </div>
                <Toggle
                  checked={autoPlayNextEpisode}
                  onChange={(v) => { setAutoPlayNextEpisode(v); saveSetting('autoPlayNextEpisode', String(v)); }}
                />
              </div>

              {/* Remember playback position */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-white text-sm font-medium">Remember Playback Position</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Resume where you left off when rewatching</div>
                </div>
                <Toggle
                  checked={rememberPlaybackPosition}
                  onChange={(v) => { setRememberPlaybackPosition(v); saveSetting('rememberPlaybackPosition', String(v)); }}
                />
              </div>

              {/* Subtitles */}
              <div className="flex items-center gap-6 p-3.5">
                <div>
                  <div className="text-cinema-text-dim text-[11px] font-medium uppercase tracking-wider mb-1">Subtitle Language</div>
                  <select
                    value={subtitleLanguage}
                    onChange={(e) => { setSubtitleLanguage(e.target.value); saveSetting('subtitleLanguage', e.target.value); }}
                    className="bg-white/[0.06] border border-cinema-border rounded-md px-3 py-1.5 text-white text-xs
                               focus:outline-none focus:border-cinema-gold/50 cursor-pointer appearance-none pr-7"
                    style={{
                      backgroundImage: `url("data:image/svg+xml,%3Csvg width='10' height='6' viewBox='0 0 10 6' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M1 1L5 5L9 1' stroke='%236b7280' stroke-width='1.5' stroke-linecap='round'/%3E%3C/svg%3E")`,
                      backgroundRepeat: 'no-repeat',
                      backgroundPosition: 'right 8px center',
                    }}
                  >
                    {SUBTITLE_LANGUAGES.map((lang) => (
                      <option key={lang} value={lang}>{lang}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <div className="text-cinema-text-dim text-[11px] font-medium uppercase tracking-wider mb-1">Subtitle Size</div>
                  <select
                    value={subtitleSize}
                    onChange={(e) => { setSubtitleSize(e.target.value); saveSetting('subtitleSize', e.target.value); }}
                    className="bg-white/[0.06] border border-cinema-border rounded-md px-3 py-1.5 text-white text-xs
                               focus:outline-none focus:border-cinema-gold/50 cursor-pointer appearance-none pr-7"
                    style={{
                      backgroundImage: `url("data:image/svg+xml,%3Csvg width='10' height='6' viewBox='0 0 10 6' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M1 1L5 5L9 1' stroke='%236b7280' stroke-width='1.5' stroke-linecap='round'/%3E%3C/svg%3E")`,
                      backgroundRepeat: 'no-repeat',
                      backgroundPosition: 'right 8px center',
                    }}
                  >
                    {SUBTITLE_SIZES.map((size) => (
                      <option key={size} value={size}>{size}</option>
                    ))}
                  </select>
                </div>
              </div>
            </div>
          </div>
        </motion.div>

        {/* ===== MUSIC CARD ===== */}
        <motion.div
          className="bg-cinema-surface rounded-xl border border-cinema-border"
          variants={cardVariants} initial="hidden" animate="visible" custom={3}
        >
          <div className="p-5">
            <h3 className="text-white text-sm font-semibold mb-4">Music</h3>
            <div className="bg-cinema-bg/50 rounded-lg border border-white/[0.04] divide-y divide-white/[0.04]">
              {/* Audio output device */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-white text-sm font-medium">Audio Output Device</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Current output for music playback</div>
                </div>
                <div className="flex items-center gap-1.5 px-3 py-1.5 bg-white/[0.06] rounded-md">
                  <svg className="w-3.5 h-3.5 text-cinema-gold/70" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                  </svg>
                  <span className="text-white/70 text-xs font-medium">System Default</span>
                </div>
              </div>

              {/* Gapless playback */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-white text-sm font-medium">Gapless Playback</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Seamless transitions between tracks in albums</div>
                </div>
                <Toggle
                  checked={gaplessPlayback}
                  onChange={(v) => { setGaplessPlayback(v); saveSetting('gaplessPlayback', String(v)); }}
                />
              </div>

              {/* Audio normalization */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-white text-sm font-medium">Audio Normalization</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Keep volume consistent across different tracks</div>
                </div>
                <Toggle
                  checked={audioNormalization}
                  onChange={(v) => { setAudioNormalization(v); saveSetting('audioNormalization', String(v)); }}
                />
              </div>

              {/* Crossfade */}
              <div className="p-3.5">
                <div className="flex items-center justify-between mb-2">
                  <div>
                    <div className="text-white text-sm font-medium">Crossfade</div>
                    <div className="text-cinema-text-dim text-[11px] mt-0.5">Blend the end of one track into the next</div>
                  </div>
                  <span className={`text-xs font-mono font-medium ${crossfadeDuration === 0 ? 'text-cinema-text-dim' : 'text-cinema-gold'}`}>
                    {crossfadeDuration === 0 ? 'Off' : `${crossfadeDuration.toFixed(1)}s`}
                  </span>
                </div>
                <input
                  type="range"
                  min={0}
                  max={12}
                  step={0.5}
                  value={crossfadeDuration}
                  onChange={(e) => {
                    const v = parseFloat(e.target.value);
                    setCrossfadeDuration(v);
                    saveSetting('crossfadeDuration', String(v));
                  }}
                  className="w-full h-1.5 bg-white/10 rounded-full appearance-none cursor-pointer
                             [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:h-4
                             [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-cinema-gold
                             [&::-webkit-slider-thumb]:shadow-md [&::-webkit-slider-thumb]:cursor-pointer"
                />
                <div className="flex justify-between mt-1">
                  <span className="text-cinema-text-dim text-[10px]">Off</span>
                  <span className="text-cinema-text-dim text-[10px]">12s</span>
                </div>
              </div>
            </div>
          </div>
        </motion.div>

        {/* ===== CACHE & STORAGE CARD ===== */}
        <motion.div
          className="bg-cinema-surface rounded-xl border border-cinema-border"
          variants={cardVariants} initial="hidden" animate="visible" custom={4}
        >
          <div className="p-5">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-white text-sm font-semibold">Cache & Storage</h3>
              <span className="text-cinema-text-dim text-xs font-medium px-2.5 py-1 bg-white/[0.06] rounded-full">
                {totalStorageUsed}
              </span>
            </div>
            <div className="bg-cinema-bg/50 rounded-lg border border-white/[0.04] divide-y divide-white/[0.04]">
              {/* Image cache */}
              <div className="flex items-center justify-between p-3.5">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-lg bg-cinema-gold/10 flex items-center justify-center">
                    <svg className="w-4 h-4 text-cinema-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                  </div>
                  <div>
                    <div className="text-white text-sm font-medium">Image Cache</div>
                    <div className="text-cinema-text-dim text-[11px]">Thumbnails, posters, and artwork</div>
                  </div>
                </div>
                <span className="text-white/60 text-xs font-mono">{imageCacheSize}</span>
              </div>

              {/* Artist profiles */}
              <div className="flex items-center justify-between p-3.5">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-lg bg-cinema-gold/10 flex items-center justify-center">
                    <svg className="w-4 h-4 text-cinema-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                  </div>
                  <div>
                    <div className="text-white text-sm font-medium">Artist Profiles</div>
                    <div className="text-cinema-text-dim text-[11px]">Artist bios, images, and metadata</div>
                  </div>
                </div>
                <span className="text-white/60 text-xs font-mono">{artistCacheSize}</span>
              </div>

              {/* Database */}
              <div className="flex items-center justify-between p-3.5">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-lg bg-cinema-blue/10 flex items-center justify-center">
                    <svg className="w-4 h-4 text-cinema-blue" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4" />
                    </svg>
                  </div>
                  <div>
                    <div className="text-white text-sm font-medium">Database</div>
                    <div className="text-cinema-text-dim text-[11px]">Library metadata and user data</div>
                  </div>
                </div>
                <span className="text-white/60 text-xs font-mono">{databaseSize}</span>
              </div>

              {/* Clear all caches */}
              <div className="flex justify-center p-3.5">
                {showClearAllConfirm ? (
                  <div className="flex items-center gap-3">
                    <span className="text-cinema-text-secondary text-xs">Clear all cached data?</span>
                    <motion.button
                      onClick={handleClearAllCaches}
                      disabled={isClearingCache}
                      className="px-4 py-1.5 text-cinema-red text-xs font-medium bg-cinema-red/10 rounded-md
                                 border border-cinema-red/15 hover:bg-cinema-red/20 transition-colors disabled:opacity-50"
                      whileTap={{ scale: 0.97 }}
                    >
                      {isClearingCache ? 'Clearing...' : 'Confirm'}
                    </motion.button>
                    <motion.button
                      onClick={() => setShowClearAllConfirm(false)}
                      className="px-4 py-1.5 text-cinema-text-secondary text-xs font-medium bg-white/[0.06] rounded-md
                                 hover:bg-white/10 transition-colors"
                      whileTap={{ scale: 0.97 }}
                    >
                      Cancel
                    </motion.button>
                  </div>
                ) : (
                  <motion.button
                    onClick={() => setShowClearAllConfirm(true)}
                    className="flex items-center gap-1.5 px-4 py-2 text-cinema-red text-xs font-medium
                               bg-cinema-red/10 rounded-lg border border-cinema-red/15
                               hover:bg-cinema-red/20 transition-colors"
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                  >
                    <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                    Clear All Caches
                  </motion.button>
                )}
              </div>
            </div>
          </div>
        </motion.div>

        {/* ===== ACCOUNT CARD ===== */}
        <motion.div
          className="bg-cinema-surface rounded-xl border border-cinema-border"
          variants={cardVariants} initial="hidden" animate="visible" custom={5}
        >
          <div className="p-5">
            <h3 className="text-white text-sm font-semibold mb-4">Account</h3>
            <div className="bg-cinema-bg/50 rounded-lg border border-white/[0.04]">
              <div className="flex items-center justify-between p-3.5">
                <div className="flex items-center gap-3">
                  {currentAccount ? (
                    <>
                      <div
                        className="w-10 h-10 rounded-xl flex items-center justify-center text-lg font-bold text-white"
                        style={{
                          background: `linear-gradient(135deg, ${currentAccount.avatar_color}, ${currentAccount.avatar_color}b3)`,
                        }}
                      >
                        {currentAccount.name.charAt(0).toUpperCase()}
                      </div>
                      <div>
                        <div className="text-white text-sm font-semibold">{currentAccount.name}</div>
                        <div className="text-cinema-text-dim text-[11px]">Active profile</div>
                      </div>
                    </>
                  ) : (
                    <>
                      <div className="w-10 h-10 rounded-xl bg-gray-500/20 flex items-center justify-center">
                        <svg className="w-5 h-5 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                        </svg>
                      </div>
                      <div>
                        <div className="text-white text-sm font-semibold">Default Profile</div>
                        <div className="text-cinema-text-dim text-[11px]">No account selected</div>
                      </div>
                    </>
                  )}
                </div>
                <div className="flex items-center gap-2">
                  <motion.button
                    onClick={() => setActiveTab('profile')}
                    className="flex items-center gap-1.5 px-3.5 py-1.5 text-cinema-gold text-xs font-medium
                               bg-cinema-gold/10 rounded-md hover:bg-cinema-gold/15 transition-colors"
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                  >
                    <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                    View Profile
                  </motion.button>
                </div>
              </div>
            </div>
          </div>
        </motion.div>

        {/* ===== NETWORK CARD ===== */}
        <motion.div
          className="bg-cinema-surface rounded-xl border border-cinema-border"
          variants={cardVariants} initial="hidden" animate="visible" custom={6}
        >
          <div className="p-5">
            <h3 className="text-white text-sm font-semibold mb-4">Network</h3>
            <div className="bg-cinema-bg/50 rounded-lg border border-white/[0.04] divide-y divide-white/[0.04]">
              {/* Server admin link */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-white text-sm font-medium">Server Administration</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Manage LAN and WAN server settings</div>
                </div>
                <motion.button
                  onClick={() => setActiveTab('admin')}
                  className="flex items-center gap-1.5 px-3.5 py-1.5 bg-cinema-gold text-black text-xs font-semibold rounded-md
                             hover:bg-cinema-gold-hover transition-colors"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                >
                  <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
                  </svg>
                  Open Network Admin
                </motion.button>
              </div>

              {/* mDNS toggle */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-white text-sm font-medium">mDNS / Bonjour Discovery</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Allow automatic server discovery on local network</div>
                </div>
                <Toggle
                  checked={mDNSDiscovery}
                  onChange={(v) => { setMDNSDiscovery(v); saveSetting('mDNSDiscovery', String(v)); }}
                />
              </div>

              {/* Default server port */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-white text-sm font-medium">Default Server Port</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Port used when starting a local server</div>
                </div>
                <input
                  type="text"
                  value={defaultServerPort}
                  onChange={(e) => {
                    const v = e.target.value.replace(/\D/g, '').slice(0, 5);
                    setDefaultServerPort(v);
                    saveSetting('defaultServerPort', v);
                  }}
                  className="w-20 bg-white/[0.06] border border-cinema-border rounded-md px-2.5 py-1.5
                             text-white text-sm font-mono text-right
                             focus:outline-none focus:border-cinema-gold/50"
                />
              </div>
            </div>
          </div>
        </motion.div>

        {/* ===== ABOUT CARD ===== */}
        <motion.div
          className="bg-cinema-surface rounded-xl border border-cinema-border"
          variants={cardVariants} initial="hidden" animate="visible" custom={7}
        >
          <div className="p-5">
            <h3 className="text-white text-sm font-semibold mb-4">About</h3>
            <div className="bg-cinema-bg/50 rounded-lg border border-white/[0.04] divide-y divide-white/[0.04]">
              {/* App identity */}
              <div className="flex items-center gap-3.5 p-3.5">
                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-cinema-red/30 to-orange-400/15 flex items-center justify-center">
                  <span className="text-2xl font-black bg-gradient-to-r from-cinema-red to-orange-400 bg-clip-text text-transparent">C</span>
                </div>
                <div>
                  <div className="text-white text-base font-bold">Cinemate</div>
                  <div className="text-cinema-text-dim text-xs">Your personal media server</div>
                </div>
              </div>

              {/* Info grid */}
              <div className="grid grid-cols-2 gap-px bg-white/[0.04]">
                {[
                  { label: 'Version', value: '3.0.0' },
                  { label: 'Build', value: '1' },
                  { label: 'Platform', value: 'Windows (Electron)' },
                  { label: 'Architecture', value: navigator.userAgent.includes('x64') ? 'x86_64' : 'x86_64' },
                ].map((item) => (
                  <div key={item.label} className="flex items-center justify-between px-3.5 py-2.5 bg-cinema-bg/50">
                    <span className="text-cinema-text-dim text-xs font-medium">{item.label}</span>
                    <span className="text-white text-xs font-medium">{item.value}</span>
                  </div>
                ))}
              </div>

              {/* Footer */}
              <div className="flex items-center justify-between p-3.5">
                <motion.button
                  className="flex items-center gap-1.5 px-3.5 py-1.5 text-cinema-gold text-xs font-medium
                             bg-cinema-gold/10 rounded-md hover:bg-cinema-gold/15 transition-colors"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                >
                  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                  </svg>
                  Check for Updates
                </motion.button>
                <span className="text-white/15 text-[11px]">Built with React + Electron</span>
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
