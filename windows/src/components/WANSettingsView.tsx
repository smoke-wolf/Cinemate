import React, { useState, useEffect, useRef, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useServer } from '../hooks/useServer';
import { api } from '../api/client';

// ---- Types ----

type TunnelType = 'ngrok' | 'cloudflared' | 'custom';
type TunnelStatus = 'disconnected' | 'connecting' | 'connected';
type WANRegion = 'us' | 'eu' | 'ap' | 'au';

interface WANSession {
  id: string;
  deviceOrIP: string;
  createdAt: Date;
}

interface WANLoginAttempt {
  id: string;
  ip: string;
  timestamp: Date;
  success: boolean;
}

// ---- Constants ----

const REGIONS: { value: WANRegion; label: string }[] = [
  { value: 'us', label: 'US' },
  { value: 'eu', label: 'Europe' },
  { value: 'ap', label: 'Asia Pacific' },
  { value: 'au', label: 'Australia' },
];

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

function StatusDot({ color }: { color: 'green' | 'orange' | 'gray' }) {
  const colorMap = {
    green: 'bg-cinema-green',
    orange: 'bg-orange-400',
    gray: 'bg-gray-500',
  };
  return <span className={`inline-block w-2 h-2 rounded-full ${colorMap[color]}`} />;
}

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

function formatRelativeDate(date: Date): string {
  const diff = Date.now() - date.getTime();
  const mins = Math.floor(diff / 60000);
  const hours = Math.floor(mins / 60);
  const days = Math.floor(hours / 24);
  if (days > 0) return `${days}d ago`;
  if (hours > 0) return `${hours}h ago`;
  if (mins > 0) return `${mins}m ago`;
  return 'Just now';
}

// ---- Main Component ----

export default function WANSettingsView() {
  const { connection } = useServer();

  // -- Tunnel state --
  const [wanEnabled, setWanEnabled] = useState(false);
  const [tunnelType, setTunnelType] = useState<TunnelType>('ngrok');
  const [tunnelStatus, setTunnelStatus] = useState<TunnelStatus>('disconnected');
  const [publicURL, setPublicURL] = useState('');
  const [tunnelUptime, setTunnelUptime] = useState('--');
  const [dataTransferred, setDataTransferred] = useState('--');
  const [tunnelStartTime, setTunnelStartTime] = useState<Date | null>(null);

  // ngrok fields
  const [ngrokAuthToken, setNgrokAuthToken] = useState('');
  const [ngrokRegion, setNgrokRegion] = useState<WANRegion>('us');
  const [ngrokReservedDomain, setNgrokReservedDomain] = useState('');

  // cloudflared fields
  const [cloudflaredUseFreeTunnel, setCloudflaredUseFreeTunnel] = useState(true);
  const [cloudflaredTunnelName, setCloudflaredTunnelName] = useState('');
  const [cloudflaredCredentialsPath, setCloudflaredCredentialsPath] = useState('');

  // custom domain fields
  const [customDomainURL, setCustomDomainURL] = useState('');
  const [sslCertPath, setSSLCertPath] = useState('');
  const [sslKeyPath, setSSLKeyPath] = useState('');

  // -- Admin auth state --
  const [adminPasswordSet, setAdminPasswordSet] = useState(false);
  const [adminPassword, setAdminPassword] = useState('');
  const [adminPasswordConfirm, setAdminPasswordConfirm] = useState('');
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newPasswordConfirm, setNewPasswordConfirm] = useState('');
  const [passwordSaved, setPasswordSaved] = useState(false);
  const [passwordError, setPasswordError] = useState('');
  const [activeSessions, setActiveSessions] = useState<WANSession[]>([]);
  const [loginAttempts, setLoginAttempts] = useState<WANLoginAttempt[]>([]);

  // -- Security state --
  const [requireAuthForWAN, setRequireAuthForWAN] = useState(true);
  const [enableRateLimiting, setEnableRateLimiting] = useState(false);
  const [rateLimitPerMinute, setRateLimitPerMinute] = useState('60');
  const [enableRequestLogging, setEnableRequestLogging] = useState(true);
  const [blockedIPs, setBlockedIPs] = useState<string[]>([]);
  const [newBlockedIP, setNewBlockedIP] = useState('');
  const [autoStopOnQuit, setAutoStopOnQuit] = useState(true);

  // -- Domain config state --
  const [testConnectionResult, setTestConnectionResult] = useState<string | null>(null);
  const [testingConnection, setTestingConnection] = useState(false);

  // -- Uptime timer --
  const uptimeIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    // Load settings from localStorage
    const saved = localStorage.getItem('cinemate.wan');
    if (saved) {
      try {
        const data = JSON.parse(saved);
        if (data.wanEnabled !== undefined) setWanEnabled(data.wanEnabled);
        if (data.tunnelType) setTunnelType(data.tunnelType);
        if (data.ngrokRegion) setNgrokRegion(data.ngrokRegion);
        if (data.adminPasswordSet) setAdminPasswordSet(data.adminPasswordSet);
        if (data.requireAuthForWAN !== undefined) setRequireAuthForWAN(data.requireAuthForWAN);
        if (data.enableRateLimiting !== undefined) setEnableRateLimiting(data.enableRateLimiting);
        if (data.rateLimitPerMinute) setRateLimitPerMinute(data.rateLimitPerMinute);
        if (data.enableRequestLogging !== undefined) setEnableRequestLogging(data.enableRequestLogging);
        if (data.autoStopOnQuit !== undefined) setAutoStopOnQuit(data.autoStopOnQuit);
        if (data.blockedIPs) setBlockedIPs(data.blockedIPs);
      } catch {}
    }

    // Start uptime timer
    uptimeIntervalRef.current = setInterval(() => {
      if (tunnelStartTime) {
        const elapsed = Math.floor((Date.now() - tunnelStartTime.getTime()) / 1000);
        const hours = Math.floor(elapsed / 3600);
        const minutes = Math.floor((elapsed % 3600) / 60);
        setTunnelUptime(hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`);
      }
    }, 60000);

    return () => {
      if (uptimeIntervalRef.current) clearInterval(uptimeIntervalRef.current);
    };
  }, [tunnelStartTime]);

  // Persist WAN settings
  const saveWANSettings = useCallback((overrides?: Record<string, unknown>) => {
    const data = {
      wanEnabled,
      tunnelType,
      ngrokRegion,
      adminPasswordSet,
      requireAuthForWAN,
      enableRateLimiting,
      rateLimitPerMinute,
      enableRequestLogging,
      autoStopOnQuit,
      blockedIPs,
      ...overrides,
    };
    localStorage.setItem('cinemate.wan', JSON.stringify(data));
  }, [wanEnabled, tunnelType, ngrokRegion, adminPasswordSet, requireAuthForWAN,
      enableRateLimiting, rateLimitPerMinute, enableRequestLogging, autoStopOnQuit, blockedIPs]);

  // -- Tunnel actions --
  const startTunnel = () => {
    setTunnelStatus('connecting');
    // Simulate tunnel startup (in production, this would invoke the Electron main process)
    setTimeout(() => {
      setTunnelStatus('connected');
      setTunnelStartTime(new Date());
      setDataTransferred('0 B');
      if (tunnelType === 'ngrok') {
        setPublicURL(ngrokReservedDomain ? `https://${ngrokReservedDomain}` : 'https://abc123.ngrok-free.app');
      } else if (tunnelType === 'cloudflared') {
        setPublicURL('https://random-words.trycloudflare.com');
      } else {
        setPublicURL(customDomainURL.startsWith('http') ? customDomainURL : `https://${customDomainURL}`);
      }
    }, 2000);
  };

  const stopTunnel = () => {
    setTunnelStatus('disconnected');
    setPublicURL('');
    setTunnelStartTime(null);
    setTunnelUptime('--');
    setDataTransferred('--');
  };

  // -- Password actions --
  const saveNewPassword = () => {
    setPasswordError('');
    if (adminPassword !== adminPasswordConfirm) {
      setPasswordError('Passwords do not match');
      return;
    }
    if (adminPassword.length < 8) {
      setPasswordError('Password must be at least 8 characters');
      return;
    }
    setAdminPasswordSet(true);
    setPasswordSaved(true);
    setAdminPassword('');
    setAdminPasswordConfirm('');
    saveWANSettings({ adminPasswordSet: true });
    setTimeout(() => setPasswordSaved(false), 2000);
  };

  const changePassword = () => {
    setPasswordError('');
    if (newPassword !== newPasswordConfirm) {
      setPasswordError('New passwords do not match');
      return;
    }
    if (newPassword.length < 8) {
      setPasswordError('Password must be at least 8 characters');
      return;
    }
    setPasswordSaved(true);
    setCurrentPassword('');
    setNewPassword('');
    setNewPasswordConfirm('');
    setTimeout(() => setPasswordSaved(false), 2000);
  };

  const revokeSession = (sessionId: string) => {
    setActiveSessions((prev) => prev.filter((s) => s.id !== sessionId));
  };

  const addBlockedIP = () => {
    const trimmed = newBlockedIP.trim();
    if (!trimmed || blockedIPs.includes(trimmed)) return;
    const updated = [...blockedIPs, trimmed];
    setBlockedIPs(updated);
    setNewBlockedIP('');
    saveWANSettings({ blockedIPs: updated });
  };

  const removeBlockedIP = (ip: string) => {
    const updated = blockedIPs.filter((i) => i !== ip);
    setBlockedIPs(updated);
    saveWANSettings({ blockedIPs: updated });
  };

  const handleTestConnection = async () => {
    if (!publicURL) return;
    setTestingConnection(true);
    setTestConnectionResult(null);
    try {
      const resp = await fetch(publicURL, { method: 'HEAD', signal: AbortSignal.timeout(10000) });
      setTestConnectionResult(`Success (${resp.status})`);
    } catch (err: any) {
      setTestConnectionResult(`Failed: ${err.message || 'No response'}`);
    }
    setTestingConnection(false);
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text).catch(() => {});
  };

  // -- Computed --
  const tunnelStatusColor: 'green' | 'orange' | 'gray' = tunnelStatus === 'connected' ? 'green' : tunnelStatus === 'connecting' ? 'orange' : 'gray';
  const tunnelStatusLabel = tunnelStatus === 'connected' ? 'Connected' : tunnelStatus === 'connecting' ? 'Connecting' : 'Disconnected';

  const sslStatusColor = (() => {
    if (tunnelType === 'ngrok' || tunnelType === 'cloudflared') return 'green' as const;
    if (sslCertPath && sslKeyPath) return 'green' as const;
    return 'gray' as const;
  })();
  const sslStatusText = (() => {
    if (tunnelType === 'ngrok') return 'Provided by ngrok';
    if (tunnelType === 'cloudflared') return 'Provided by cloudflared';
    if (sslCertPath && sslKeyPath) return 'Certificate configured';
    return 'Not configured';
  })();

  return (
    <div className="h-full overflow-y-auto">
      <div className="p-8 max-w-4xl space-y-6">
        {/* Header */}
        <motion.div
          className="flex items-center justify-between"
          initial={{ opacity: 0, x: -10 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.3 }}
        >
          <div className="flex items-center gap-3.5">
            <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-cinema-gold/20 to-cinema-gold/5 flex items-center justify-center">
              <svg className="w-6 h-6 text-cinema-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
              </svg>
            </div>
            <div>
              <h2 className="text-white text-2xl font-bold">WAN Settings</h2>
              <p className="text-cinema-text-secondary text-sm">Internet access, tunnels, and remote security</p>
            </div>
          </div>

          {/* Quick status indicators */}
          {wanEnabled && (
            <div className="flex items-center gap-2.5">
              {adminPasswordSet && (
                <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-cinema-green/10 text-cinema-green text-[11px] font-medium">
                  <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clipRule="evenodd" />
                  </svg>
                  Secured
                </div>
              )}
              {enableRateLimiting && (
                <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-cinema-gold/10 text-cinema-gold text-[11px] font-medium">
                  <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                  Rate Limited
                </div>
              )}
            </div>
          )}
        </motion.div>

        {/* Security warning */}
        <AnimatePresence>
          {wanEnabled && !adminPasswordSet && (
            <motion.div
              className="flex items-start gap-3 p-4 rounded-xl bg-orange-400/[0.08] border border-orange-400/25"
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
            >
              <svg className="w-5 h-5 text-orange-400 shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
              </svg>
              <div>
                <div className="text-orange-400 text-sm font-semibold">Admin password not set</div>
                <div className="text-orange-400/80 text-xs mt-0.5">
                  WAN access is enabled but no admin password has been configured. Anyone with the tunnel URL can access your server. Set a password below to secure remote access.
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* ===== TUNNEL MANAGEMENT CARD ===== */}
        <motion.div
          className="bg-cinema-surface rounded-xl border border-cinema-border"
          variants={cardVariants} initial="hidden" animate="visible" custom={0}
        >
          <div className="p-5">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-white text-sm font-semibold">Tunnel Management</h3>
              <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold
                              ${tunnelStatusColor === 'green' ? 'bg-cinema-green/10 text-cinema-green border border-cinema-green/20' :
                                tunnelStatusColor === 'orange' ? 'bg-orange-400/10 text-orange-400 border border-orange-400/20' :
                                'bg-gray-500/10 text-gray-500 border border-gray-500/20'}`}>
                <StatusDot color={tunnelStatusColor} />
                {tunnelStatusLabel}
              </div>
            </div>

            <div className="space-y-4">
              {/* Master switch */}
              <div className="flex items-center justify-between p-3.5 bg-cinema-bg/50 rounded-lg border border-white/[0.04]">
                <div>
                  <div className="text-white text-sm font-medium">Enable WAN Access</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Expose your Cinemate server to the internet via a secure tunnel</div>
                </div>
                <Toggle
                  checked={wanEnabled}
                  onChange={(v) => { setWanEnabled(v); saveWANSettings({ wanEnabled: v }); }}
                />
              </div>

              <AnimatePresence>
                {wanEnabled && (
                  <motion.div
                    className="space-y-4"
                    initial={{ opacity: 0, height: 0 }}
                    animate={{ opacity: 1, height: 'auto' }}
                    exit={{ opacity: 0, height: 0 }}
                  >
                    {/* Tunnel type picker */}
                    <div className="px-1">
                      <div className="text-cinema-text-dim text-xs font-medium mb-2">Tunnel Provider</div>
                      <div className="flex bg-cinema-bg/50 rounded-lg p-1 border border-white/[0.04]">
                        {([
                          { value: 'ngrok' as TunnelType, label: 'ngrok' },
                          { value: 'cloudflared' as TunnelType, label: 'cloudflared' },
                          { value: 'custom' as TunnelType, label: 'Custom Domain' },
                        ]).map((opt) => (
                          <button
                            key={opt.value}
                            onClick={() => { setTunnelType(opt.value); saveWANSettings({ tunnelType: opt.value }); }}
                            className={`flex-1 py-2 text-xs font-medium rounded-md transition-all duration-200
                                        ${tunnelType === opt.value
                                          ? 'bg-cinema-gold text-black shadow-sm'
                                          : 'text-cinema-text-secondary hover:text-white'}`}
                          >
                            {opt.label}
                          </button>
                        ))}
                      </div>
                    </div>

                    {/* Provider-specific fields */}
                    <div className="bg-cinema-bg/50 rounded-lg border border-white/[0.04] p-3.5 space-y-3">
                      {tunnelType === 'ngrok' && (
                        <>
                          <FieldRow label="Auth Token" placeholder="Enter ngrok auth token" value={ngrokAuthToken} onChange={setNgrokAuthToken} isSecure />
                          <div>
                            <div className="text-cinema-text-dim text-xs font-medium mb-1.5">Region</div>
                            <div className="flex bg-cinema-bg/50 rounded-md p-0.5 border border-white/[0.04]">
                              {REGIONS.map((r) => (
                                <button
                                  key={r.value}
                                  onClick={() => { setNgrokRegion(r.value); saveWANSettings({ ngrokRegion: r.value }); }}
                                  className={`flex-1 py-1.5 text-[11px] font-medium rounded transition-all duration-200
                                              ${ngrokRegion === r.value
                                                ? 'bg-cinema-gold text-black'
                                                : 'text-cinema-text-dim hover:text-white'}`}
                                >
                                  {r.label}
                                </button>
                              ))}
                            </div>
                          </div>
                          <FieldRow label="Reserved Domain (optional)" placeholder="myapp.ngrok.io" value={ngrokReservedDomain} onChange={setNgrokReservedDomain} />
                        </>
                      )}

                      {tunnelType === 'cloudflared' && (
                        <>
                          <div className="flex items-center justify-between">
                            <div>
                              <div className="text-white text-sm font-medium">Free Quick Tunnel</div>
                              <div className="text-cinema-text-dim text-[11px] mt-0.5">No account needed -- Cloudflare assigns a random .trycloudflare.com URL</div>
                            </div>
                            <Toggle checked={cloudflaredUseFreeTunnel} onChange={setCloudflaredUseFreeTunnel} />
                          </div>
                          {!cloudflaredUseFreeTunnel && (
                            <>
                              <FieldRow label="Tunnel Name" placeholder="cinemate-tunnel" value={cloudflaredTunnelName} onChange={setCloudflaredTunnelName} />
                              <FieldRow label="Credentials File" placeholder="~/.cloudflared/credentials.json" value={cloudflaredCredentialsPath} onChange={setCloudflaredCredentialsPath} />
                            </>
                          )}
                        </>
                      )}

                      {tunnelType === 'custom' && (
                        <>
                          <FieldRow label="Domain URL" placeholder="https://cinema.example.com" value={customDomainURL} onChange={setCustomDomainURL} />
                          <FieldRow label="SSL Certificate" placeholder="/path/to/cert.pem" value={sslCertPath} onChange={setSSLCertPath} />
                          <FieldRow label="SSL Private Key" placeholder="/path/to/key.pem" value={sslKeyPath} onChange={setSSLKeyPath} />
                        </>
                      )}
                    </div>

                    {/* Start / Stop button */}
                    <motion.button
                      onClick={tunnelStatus === 'connected' ? stopTunnel : startTunnel}
                      disabled={tunnelStatus === 'connecting'}
                      className={`w-full flex items-center justify-center gap-2 py-3 rounded-lg text-sm font-semibold
                                  transition-all duration-200 disabled:opacity-50
                                  ${tunnelStatus === 'connected'
                                    ? 'bg-cinema-red/80 text-white hover:bg-cinema-red'
                                    : 'bg-cinema-gold text-black hover:bg-cinema-gold-hover'}`}
                      whileHover={{ scale: 1.01 }}
                      whileTap={{ scale: 0.99 }}
                    >
                      {tunnelStatus === 'connecting' ? (
                        <div className="w-4 h-4 border-2 border-current/30 border-t-current rounded-full animate-spin" />
                      ) : (
                        <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                          {tunnelStatus === 'connected' ? (
                            <rect x="6" y="6" width="8" height="8" rx="1" />
                          ) : (
                            <path d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z" />
                          )}
                        </svg>
                      )}
                      {tunnelStatus === 'connected' ? 'Stop Tunnel' : tunnelStatus === 'connecting' ? 'Connecting...' : 'Start Tunnel'}
                    </motion.button>

                    {/* Tunnel status display */}
                    <AnimatePresence>
                      {tunnelStatus === 'connected' && publicURL && (
                        <motion.div
                          className="bg-cinema-bg/50 rounded-lg border border-white/[0.04] p-3.5 space-y-3.5"
                          initial={{ opacity: 0, height: 0 }}
                          animate={{ opacity: 1, height: 'auto' }}
                          exit={{ opacity: 0, height: 0 }}
                        >
                          {/* Public URL */}
                          <div className="flex items-center justify-between">
                            <div>
                              <div className="text-cinema-text-dim text-[10px] font-medium uppercase tracking-wider">Public URL</div>
                              <div className="text-cinema-gold text-sm font-mono mt-0.5 select-all">{publicURL}</div>
                            </div>
                            <motion.button
                              onClick={() => copyToClipboard(publicURL)}
                              className="p-1.5 text-cinema-text-dim hover:text-white bg-white/[0.06] rounded-md transition-colors"
                              whileTap={{ scale: 0.9 }}
                            >
                              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                              </svg>
                            </motion.button>
                          </div>

                          {/* Stats */}
                          <div className="flex gap-6">
                            <div>
                              <div className="text-cinema-text-dim text-[10px] font-medium uppercase tracking-wider">Uptime</div>
                              <div className="text-white text-sm font-medium mt-0.5">{tunnelUptime}</div>
                            </div>
                            <div>
                              <div className="text-cinema-text-dim text-[10px] font-medium uppercase tracking-wider">Data Transferred</div>
                              <div className="text-white text-sm font-medium mt-0.5">{dataTransferred}</div>
                            </div>
                            <div>
                              <div className="text-cinema-text-dim text-[10px] font-medium uppercase tracking-wider">Provider</div>
                              <div className="text-white text-sm font-medium mt-0.5">{tunnelType}</div>
                            </div>
                          </div>

                          {/* QR code placeholder */}
                          <div className="flex flex-col items-center gap-2 pt-2">
                            <div className="text-cinema-text-dim text-[11px]">Scan to connect from your phone</div>
                            <div className="w-36 h-36 bg-white rounded-lg flex items-center justify-center">
                              <div className="text-black/30 text-xs text-center px-4">
                                QR code for<br />{publicURL}
                              </div>
                            </div>
                          </div>
                        </motion.div>
                      )}
                    </AnimatePresence>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </div>
        </motion.div>

        {/* ===== ADMIN AUTHENTICATION CARD ===== */}
        <motion.div
          className="bg-cinema-surface rounded-xl border border-cinema-border"
          variants={cardVariants} initial="hidden" animate="visible" custom={1}
        >
          <div className="p-5">
            <h3 className="text-white text-sm font-semibold mb-4">Admin Authentication</h3>
            <div className="bg-cinema-bg/50 rounded-lg border border-white/[0.04] divide-y divide-white/[0.04]">
              {/* Password setup / change */}
              <div className="p-3.5 space-y-3">
                {!adminPasswordSet ? (
                  <>
                    <div>
                      <div className="text-white text-sm font-medium">Set Admin Password</div>
                      <div className="text-cinema-text-dim text-[11px] mt-0.5">Required to manage your server over WAN connections</div>
                    </div>
                    <FieldRow label="Password" placeholder="Enter password" value={adminPassword} onChange={setAdminPassword} isSecure />
                    <FieldRow label="Confirm Password" placeholder="Confirm password" value={adminPasswordConfirm} onChange={setAdminPasswordConfirm} isSecure />
                    {passwordError && <div className="text-cinema-red text-[11px]">{passwordError}</div>}
                    <div className="flex justify-end">
                      <motion.button
                        onClick={saveNewPassword}
                        disabled={!adminPassword || !adminPasswordConfirm}
                        className={`flex items-center gap-1.5 px-4 py-2 text-xs font-medium rounded-lg transition-colors disabled:opacity-50
                                    ${passwordSaved
                                      ? 'bg-cinema-green/15 text-cinema-green'
                                      : 'bg-cinema-gold text-black hover:bg-cinema-gold-hover'}`}
                        whileHover={{ scale: 1.02 }}
                        whileTap={{ scale: 0.98 }}
                      >
                        <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                            d={passwordSaved ? 'M5 13l4 4L19 7' : 'M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z'} />
                        </svg>
                        {passwordSaved ? 'Saved' : 'Set Password'}
                      </motion.button>
                    </div>
                  </>
                ) : (
                  <>
                    <div className="flex items-center gap-2">
                      <svg className="w-4 h-4 text-cinema-green" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clipRule="evenodd" />
                      </svg>
                      <span className="text-white text-sm font-medium">Admin password is set</span>
                    </div>
                    <FieldRow label="Current Password" placeholder="Enter current password" value={currentPassword} onChange={setCurrentPassword} isSecure />
                    <FieldRow label="New Password" placeholder="Enter new password" value={newPassword} onChange={setNewPassword} isSecure />
                    <FieldRow label="Confirm New Password" placeholder="Confirm new password" value={newPasswordConfirm} onChange={setNewPasswordConfirm} isSecure />
                    {passwordError && <div className="text-cinema-red text-[11px]">{passwordError}</div>}
                    <div className="flex justify-end">
                      <motion.button
                        onClick={changePassword}
                        disabled={!currentPassword || !newPassword || !newPasswordConfirm}
                        className={`flex items-center gap-1.5 px-4 py-2 text-xs font-medium rounded-lg transition-colors disabled:opacity-50
                                    ${passwordSaved
                                      ? 'bg-cinema-green/15 text-cinema-green'
                                      : 'bg-cinema-gold text-black hover:bg-cinema-gold-hover'}`}
                        whileHover={{ scale: 1.02 }}
                        whileTap={{ scale: 0.98 }}
                      >
                        <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                            d={passwordSaved ? 'M5 13l4 4L19 7' : 'M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15'} />
                        </svg>
                        {passwordSaved ? 'Updated' : 'Change Password'}
                      </motion.button>
                    </div>
                  </>
                )}
              </div>

              {/* Active sessions */}
              <div className="p-3.5">
                <div className="flex items-center justify-between mb-2.5">
                  <span className="text-cinema-text-dim text-xs font-medium">Active Sessions</span>
                  <span className="text-cinema-text-dim text-[11px]">{activeSessions.length} active</span>
                </div>
                {activeSessions.length === 0 ? (
                  <div className="text-white/20 text-xs py-2">No active sessions</div>
                ) : (
                  <div className="space-y-1">
                    {activeSessions.map((session) => (
                      <div key={session.id} className="flex items-center justify-between px-2.5 py-2 bg-white/[0.02] rounded-md">
                        <div>
                          <div className="text-white text-xs font-medium">{session.deviceOrIP}</div>
                          <div className="text-cinema-text-dim text-[10px]">{formatRelativeDate(session.createdAt)}</div>
                        </div>
                        <motion.button
                          onClick={() => revokeSession(session.id)}
                          className="px-2.5 py-1 text-cinema-red text-[11px] font-medium bg-cinema-red/10 rounded-md
                                     border border-cinema-red/20 hover:bg-cinema-red/20 transition-colors"
                          whileTap={{ scale: 0.97 }}
                        >
                          Revoke
                        </motion.button>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Login history */}
              <div className="p-3.5">
                <div className="text-cinema-text-dim text-xs font-medium mb-2.5">Login History (last 10)</div>
                {loginAttempts.length === 0 ? (
                  <div className="text-white/20 text-xs py-2">No login attempts recorded</div>
                ) : (
                  <div className="space-y-1">
                    {loginAttempts.slice(0, 10).map((attempt) => (
                      <div key={attempt.id} className="flex items-center gap-2 px-2.5 py-1.5 bg-white/[0.02] rounded-md">
                        <span className={`w-1.5 h-1.5 rounded-full ${attempt.success ? 'bg-cinema-green' : 'bg-cinema-red'}`} />
                        <span className="text-white text-xs font-mono">{attempt.ip}</span>
                        <span className="flex-1" />
                        <span className={`text-[11px] font-medium ${attempt.success ? 'text-cinema-green' : 'text-cinema-red'}`}>
                          {attempt.success ? 'Success' : 'Failed'}
                        </span>
                        <span className="text-cinema-text-dim text-[10px]">{formatRelativeDate(attempt.timestamp)}</span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>
        </motion.div>

        {/* ===== SECURITY SETTINGS CARD ===== */}
        <motion.div
          className="bg-cinema-surface rounded-xl border border-cinema-border"
          variants={cardVariants} initial="hidden" animate="visible" custom={2}
        >
          <div className="p-5">
            <h3 className="text-white text-sm font-semibold mb-4">Security</h3>
            <div className="bg-cinema-bg/50 rounded-lg border border-white/[0.04] divide-y divide-white/[0.04]">
              {/* Require auth */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-white text-sm font-medium">Require Authentication for All WAN Requests</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Every request from the internet must include valid credentials</div>
                </div>
                <Toggle
                  checked={requireAuthForWAN}
                  onChange={(v) => { setRequireAuthForWAN(v); saveWANSettings({ requireAuthForWAN: v }); }}
                />
              </div>

              {/* Rate limiting */}
              <div className="p-3.5 space-y-2.5">
                <div className="flex items-center justify-between">
                  <div>
                    <div className="text-white text-sm font-medium">Enable Rate Limiting</div>
                    <div className="text-cinema-text-dim text-[11px] mt-0.5">Throttle incoming requests to prevent abuse</div>
                  </div>
                  <Toggle
                    checked={enableRateLimiting}
                    onChange={(v) => { setEnableRateLimiting(v); saveWANSettings({ enableRateLimiting: v }); }}
                  />
                </div>
                <AnimatePresence>
                  {enableRateLimiting && (
                    <motion.div
                      className="flex items-center gap-2"
                      initial={{ opacity: 0, height: 0 }}
                      animate={{ opacity: 1, height: 'auto' }}
                      exit={{ opacity: 0, height: 0 }}
                    >
                      <span className="text-cinema-text-dim text-xs">Max requests per minute:</span>
                      <input
                        type="text"
                        value={rateLimitPerMinute}
                        onChange={(e) => {
                          const v = e.target.value.replace(/\D/g, '').slice(0, 5);
                          setRateLimitPerMinute(v);
                          saveWANSettings({ rateLimitPerMinute: v });
                        }}
                        className="w-20 bg-white/[0.06] border border-cinema-border rounded-md px-2.5 py-1.5
                                   text-white text-xs font-mono focus:outline-none focus:border-cinema-gold/50"
                      />
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>

              {/* Request logging */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-white text-sm font-medium">Enable Request Logging</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Log all incoming WAN requests for auditing</div>
                </div>
                <Toggle
                  checked={enableRequestLogging}
                  onChange={(v) => { setEnableRequestLogging(v); saveWANSettings({ enableRequestLogging: v }); }}
                />
              </div>

              {/* Auto-stop on quit */}
              <div className="flex items-center justify-between p-3.5">
                <div>
                  <div className="text-white text-sm font-medium">Auto-Stop Tunnel on App Quit</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Automatically close the tunnel when Cinemate exits</div>
                </div>
                <Toggle
                  checked={autoStopOnQuit}
                  onChange={(v) => { setAutoStopOnQuit(v); saveWANSettings({ autoStopOnQuit: v }); }}
                />
              </div>

              {/* IP Blocklist */}
              <div className="p-3.5 space-y-2.5">
                <div>
                  <div className="text-white text-sm font-medium">IP Blocklist</div>
                  <div className="text-cinema-text-dim text-[11px] mt-0.5">Blocked IPs will be denied access to your server</div>
                </div>

                {blockedIPs.length > 0 && (
                  <div className="space-y-1">
                    {blockedIPs.map((ip) => (
                      <div key={ip} className="flex items-center gap-2 px-2.5 py-1.5 bg-white/[0.03] rounded-md">
                        <svg className="w-3 h-3 text-cinema-red/70 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
                        </svg>
                        <span className="text-white text-xs font-mono flex-1">{ip}</span>
                        <button
                          onClick={() => removeBlockedIP(ip)}
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

                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    value={newBlockedIP}
                    onChange={(e) => setNewBlockedIP(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && addBlockedIP()}
                    placeholder="IP address to block"
                    className="w-48 bg-white/[0.06] border border-cinema-border rounded-md px-2.5 py-1.5
                               text-white text-xs font-mono placeholder:text-cinema-text-dim
                               focus:outline-none focus:border-cinema-gold/50"
                  />
                  <motion.button
                    onClick={addBlockedIP}
                    disabled={!newBlockedIP.trim()}
                    className="px-3.5 py-1.5 bg-cinema-red/70 text-white text-xs font-medium rounded-md
                               hover:bg-cinema-red transition-colors disabled:opacity-50"
                    whileTap={{ scale: 0.97 }}
                  >
                    Block
                  </motion.button>
                </div>
              </div>
            </div>
          </div>
        </motion.div>

        {/* ===== DOMAIN CONFIGURATION CARD ===== */}
        <motion.div
          className="bg-cinema-surface rounded-xl border border-cinema-border"
          variants={cardVariants} initial="hidden" animate="visible" custom={3}
        >
          <div className="p-5">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-white text-sm font-semibold">Domain Configuration</h3>
              <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold
                              ${sslStatusColor === 'green' ? 'bg-cinema-green/10 text-cinema-green border border-cinema-green/20' :
                                'bg-gray-500/10 text-gray-500 border border-gray-500/20'}`}>
                <StatusDot color={sslStatusColor} />
                {sslStatusText}
              </div>
            </div>

            <div className="bg-cinema-bg/50 rounded-lg border border-white/[0.04] p-3.5 space-y-3">
              <FieldRow label="Custom Domain" placeholder="cinema.example.com" value={customDomainURL} onChange={setCustomDomainURL} />

              {/* DNS hint */}
              {tunnelStatus === 'connected' && publicURL && customDomainURL && (
                <div className="bg-white/[0.03] rounded-md p-2.5">
                  <div className="text-cinema-text-dim text-[11px] font-medium mb-1">DNS Configuration</div>
                  <div className="flex items-center gap-2 text-[11px]">
                    <svg className="w-3 h-3 text-cinema-gold/60 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
                    </svg>
                    <span className="text-white/50">Point a CNAME record for</span>
                    <span className="text-white/80 font-mono">{customDomainURL}</span>
                    <span className="text-white/50">to your tunnel URL</span>
                  </div>
                </div>
              )}

              {/* Test connection */}
              <div className="flex items-center justify-between">
                {testConnectionResult && (
                  <div className="flex items-center gap-1.5">
                    <svg className={`w-3.5 h-3.5 ${testConnectionResult.includes('Success') ? 'text-cinema-green' : 'text-cinema-red'}`} fill="currentColor" viewBox="0 0 20 20">
                      {testConnectionResult.includes('Success') ? (
                        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                      ) : (
                        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                      )}
                    </svg>
                    <span className={`text-[11px] ${testConnectionResult.includes('Success') ? 'text-cinema-green' : 'text-cinema-red'}`}>
                      {testConnectionResult}
                    </span>
                  </div>
                )}
                <div className="flex-1" />
                <motion.button
                  onClick={handleTestConnection}
                  disabled={testingConnection || !publicURL}
                  className="flex items-center gap-1.5 px-4 py-2 text-cinema-gold text-xs font-medium rounded-lg
                             border border-cinema-gold/40 hover:bg-cinema-gold/10 transition-colors disabled:opacity-50"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                >
                  {testingConnection ? (
                    <div className="w-3.5 h-3.5 border-2 border-cinema-gold/30 border-t-cinema-gold rounded-full animate-spin" />
                  ) : (
                    <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.111 16.404a5.5 5.5 0 017.778 0M12 20h.01m-7.08-7.071c3.904-3.905 10.236-3.905 14.141 0M1.394 9.393c5.857-5.858 15.355-5.858 21.213 0" />
                    </svg>
                  )}
                  {testingConnection ? 'Testing...' : 'Test Connection'}
                </motion.button>
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}

// ---- Reusable field row ----

function FieldRow({
  label,
  placeholder,
  value,
  onChange,
  isSecure = false,
}: {
  label: string;
  placeholder: string;
  value: string;
  onChange: (v: string) => void;
  isSecure?: boolean;
}) {
  return (
    <div>
      <div className="text-cinema-text-dim text-xs font-medium mb-1">{label}</div>
      <input
        type={isSecure ? 'password' : 'text'}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full bg-white/[0.06] border border-cinema-border rounded-md px-3 py-2
                   text-white text-sm placeholder:text-cinema-text-dim
                   focus:outline-none focus:border-cinema-gold/50 transition-colors"
      />
    </div>
  );
}
