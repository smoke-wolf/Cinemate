import React, { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

// ─── Types ───

interface DownloadRecord {
  id: string;
  title: string;
  subtitle?: string;
  status: 'downloading' | 'paused' | 'failed' | 'completed';
  progress: number;
  bytesDownloaded: number;
  totalBytes: number;
  errorMessage?: string;
  completedAt?: number;
  localFilePath?: string;
}

// ─── Helpers ───

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  const value = bytes / Math.pow(1024, i);
  return `${value.toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
}

function formatRelativeTime(timestamp: number): string {
  const diff = Date.now() - timestamp;
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

const STORAGE_KEY = 'cinemate_downloads';

function loadDownloads(): DownloadRecord[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

function saveDownloads(records: DownloadRecord[]) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(records));
}

// ─── Status helpers ───

function statusIcon(status: DownloadRecord['status']) {
  switch (status) {
    case 'downloading':
      return (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
        </svg>
      );
    case 'paused':
      return (
        <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
          <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
        </svg>
      );
    case 'failed':
      return (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        </svg>
      );
    case 'completed':
      return (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
        </svg>
      );
  }
}

function statusColor(status: DownloadRecord['status']): string {
  switch (status) {
    case 'downloading': return 'text-cinema-blue';
    case 'paused': return 'text-yellow-500';
    case 'failed': return 'text-cinema-red';
    case 'completed': return 'text-cinema-green';
  }
}

function statusBg(status: DownloadRecord['status']): string {
  switch (status) {
    case 'downloading': return 'bg-cinema-blue/10';
    case 'paused': return 'bg-yellow-500/10';
    case 'failed': return 'bg-cinema-red/10';
    case 'completed': return 'bg-cinema-green/10';
  }
}

// ─── Component ───

const cardVariants = {
  hidden: { opacity: 0, y: 15 },
  visible: (i: number) => ({
    opacity: 1,
    y: 0,
    transition: { delay: i * 0.06, duration: 0.35, ease: [0.4, 0, 0.2, 1] },
  }),
};

export default function DownloadQueueView() {
  const [downloads, setDownloads] = useState<DownloadRecord[]>(loadDownloads);

  // Persist to localStorage
  useEffect(() => {
    saveDownloads(downloads);
  }, [downloads]);

  const activeDownloads = downloads.filter((d) => d.status !== 'completed');
  const completedDownloads = downloads.filter((d) => d.status === 'completed');
  const totalDownloadedSize = completedDownloads.reduce((acc, d) => acc + d.totalBytes, 0);

  const cancelDownload = useCallback((id: string) => {
    setDownloads((prev) => prev.filter((d) => d.id !== id));
  }, []);

  const retryDownload = useCallback((id: string) => {
    setDownloads((prev) =>
      prev.map((d) =>
        d.id === id ? { ...d, status: 'downloading' as const, progress: 0, bytesDownloaded: 0, errorMessage: undefined } : d
      )
    );
  }, []);

  const pauseDownload = useCallback((id: string) => {
    setDownloads((prev) =>
      prev.map((d) =>
        d.id === id ? { ...d, status: 'paused' as const } : d
      )
    );
  }, []);

  const resumeDownload = useCallback((id: string) => {
    setDownloads((prev) =>
      prev.map((d) =>
        d.id === id ? { ...d, status: 'downloading' as const } : d
      )
    );
  }, []);

  const deleteRecord = useCallback((id: string) => {
    setDownloads((prev) => prev.filter((d) => d.id !== id));
  }, []);

  const clearCompleted = useCallback(() => {
    setDownloads((prev) => prev.filter((d) => d.status !== 'completed'));
  }, []);

  const isEmpty = activeDownloads.length === 0 && completedDownloads.length === 0;

  return (
    <div className="h-full overflow-y-auto p-6">
      {/* Header */}
      <motion.div
        className="flex items-center gap-4 mb-6"
        initial={{ opacity: 0, x: -20 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.4 }}
      >
        <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-cinema-blue/20 to-cinema-blue/5 flex items-center justify-center">
          <svg className="w-6 h-6 text-cinema-blue" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
          </svg>
        </div>
        <div>
          <h2 className="text-white text-2xl font-bold">Downloads</h2>
          <p className="text-cinema-text-dim text-sm">
            {activeDownloads.length} active, {completedDownloads.length} completed
          </p>
        </div>
        <div className="flex-1" />
        {completedDownloads.length > 0 && (
          <motion.button
            onClick={clearCompleted}
            className="flex items-center gap-1.5 px-3.5 py-2 text-xs font-medium text-cinema-text-secondary
                       bg-white/[0.06] hover:bg-white/[0.1] rounded-lg transition-colors duration-200"
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
          >
            <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
            Clear Completed
          </motion.button>
        )}
      </motion.div>

      {/* Total downloaded stat */}
      {completedDownloads.length > 0 && (
        <motion.div
          className="bg-cinema-surface rounded-xl p-4 border border-cinema-border mb-6 flex items-center gap-3"
          variants={cardVariants}
          initial="hidden"
          animate="visible"
          custom={0}
        >
          <div className="w-10 h-10 rounded-lg bg-cinema-green/10 flex items-center justify-center text-cinema-green">
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
            </svg>
          </div>
          <div>
            <div className="text-white text-lg font-bold">{formatBytes(totalDownloadedSize)}</div>
            <div className="text-cinema-text-dim text-xs">Total Downloaded</div>
          </div>
        </motion.div>
      )}

      {/* Empty state */}
      {isEmpty && (
        <motion.div
          className="flex flex-col items-center justify-center py-24 text-center"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2, duration: 0.4 }}
        >
          <svg className="w-16 h-16 mb-4 text-white/[0.08]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
          </svg>
          <p className="text-white/30 text-lg font-semibold mb-1">No Downloads</p>
          <p className="text-white/[0.15] text-sm max-w-xs">
            Downloads from your server or external drives will appear here
          </p>
        </motion.div>
      )}

      {/* Active downloads */}
      {activeDownloads.length > 0 && (
        <motion.div
          className="mb-6"
          variants={cardVariants}
          initial="hidden"
          animate="visible"
          custom={1}
        >
          <h3 className="text-white text-sm font-semibold mb-3">Active Downloads</h3>
          <div className="bg-cinema-surface rounded-xl border border-cinema-border overflow-hidden">
            <AnimatePresence>
              {activeDownloads.map((record, i) => (
                <motion.div
                  key={record.id}
                  className="flex items-center gap-3.5 px-4 py-3.5 border-b border-cinema-border/50 last:border-b-0
                             hover:bg-cinema-bg/30 transition-colors duration-150"
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -20, height: 0 }}
                  transition={{ delay: i * 0.04, duration: 0.2 }}
                >
                  {/* Status icon */}
                  <div className={`w-10 h-10 rounded-lg ${statusBg(record.status)} flex items-center justify-center ${statusColor(record.status)} shrink-0`}>
                    {statusIcon(record.status)}
                  </div>

                  {/* Title + progress */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-white text-sm font-medium truncate">{record.title}</span>
                      {record.subtitle && (
                        <span className="text-cinema-text-dim text-xs truncate">{record.subtitle}</span>
                      )}
                    </div>

                    {/* Progress bar */}
                    <div className="h-1.5 bg-cinema-bg rounded-full overflow-hidden mb-1.5">
                      <motion.div
                        className="h-full rounded-full bg-gradient-to-r from-cinema-blue to-cinema-blue/70"
                        initial={{ width: 0 }}
                        animate={{ width: `${record.progress * 100}%` }}
                        transition={{ duration: 0.4, ease: [0.4, 0, 0.2, 1] }}
                      />
                    </div>

                    <div className="flex items-center justify-between">
                      <span className="text-cinema-text-dim text-[11px] tabular-nums">
                        {formatBytes(record.bytesDownloaded)} of {formatBytes(record.totalBytes)}
                      </span>
                      <span className="text-cinema-blue text-[11px] font-medium tabular-nums">
                        {Math.round(record.progress * 100)}%
                      </span>
                    </div>

                    {record.status === 'failed' && record.errorMessage && (
                      <p className="text-cinema-red/80 text-[11px] mt-1 truncate">{record.errorMessage}</p>
                    )}
                  </div>

                  {/* Controls */}
                  <div className="flex items-center gap-1.5 shrink-0">
                    {record.status === 'failed' && (
                      <motion.button
                        onClick={() => retryDownload(record.id)}
                        className="w-8 h-8 rounded-lg flex items-center justify-center text-orange-400 hover:bg-orange-400/10 transition-colors duration-150"
                        whileTap={{ scale: 0.9 }}
                        title="Retry"
                      >
                        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                        </svg>
                      </motion.button>
                    )}
                    {record.status === 'paused' && (
                      <motion.button
                        onClick={() => resumeDownload(record.id)}
                        className="w-8 h-8 rounded-lg flex items-center justify-center text-cinema-green hover:bg-cinema-green/10 transition-colors duration-150"
                        whileTap={{ scale: 0.9 }}
                        title="Resume"
                      >
                        <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M8 5v14l11-7z" />
                        </svg>
                      </motion.button>
                    )}
                    {record.status === 'downloading' && (
                      <motion.button
                        onClick={() => pauseDownload(record.id)}
                        className="w-8 h-8 rounded-lg flex items-center justify-center text-yellow-500 hover:bg-yellow-500/10 transition-colors duration-150"
                        whileTap={{ scale: 0.9 }}
                        title="Pause"
                      >
                        <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
                        </svg>
                      </motion.button>
                    )}
                    <motion.button
                      onClick={() => cancelDownload(record.id)}
                      className="w-8 h-8 rounded-lg flex items-center justify-center text-cinema-red/60 hover:text-cinema-red hover:bg-cinema-red/10 transition-colors duration-150"
                      whileTap={{ scale: 0.9 }}
                      title="Cancel"
                    >
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </motion.button>
                  </div>
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        </motion.div>
      )}

      {/* Completed downloads */}
      {completedDownloads.length > 0 && (
        <motion.div
          variants={cardVariants}
          initial="hidden"
          animate="visible"
          custom={2}
        >
          <h3 className="text-white text-sm font-semibold mb-3">Completed</h3>
          <div className="bg-cinema-surface rounded-xl border border-cinema-border overflow-hidden">
            <AnimatePresence>
              {completedDownloads.map((record, i) => (
                <motion.div
                  key={record.id}
                  className="flex items-center gap-3.5 px-4 py-3.5 border-b border-cinema-border/50 last:border-b-0
                             hover:bg-cinema-bg/30 transition-colors duration-150"
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -20, height: 0 }}
                  transition={{ delay: i * 0.04, duration: 0.2 }}
                >
                  {/* Check icon */}
                  <div className="w-10 h-10 rounded-lg bg-cinema-green/10 flex items-center justify-center text-cinema-green shrink-0">
                    <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                  </div>

                  {/* Title + info */}
                  <div className="flex-1 min-w-0">
                    <p className="text-white text-sm font-medium truncate">{record.title}</p>
                    <div className="flex items-center gap-2 mt-0.5">
                      <span className="text-cinema-text-dim text-[11px] tabular-nums">{formatBytes(record.totalBytes)}</span>
                      {record.completedAt && (
                        <span className="text-cinema-text-dim text-[11px]">{formatRelativeTime(record.completedAt)}</span>
                      )}
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="flex items-center gap-1.5 shrink-0">
                    <motion.button
                      onClick={() => deleteRecord(record.id)}
                      className="w-8 h-8 rounded-lg flex items-center justify-center text-cinema-red/50 hover:text-cinema-red hover:bg-cinema-red/10 transition-colors duration-150"
                      whileTap={{ scale: 0.9 }}
                      title="Remove"
                    >
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </motion.button>
                  </div>
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        </motion.div>
      )}
    </div>
  );
}
