import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import type { Movie, TimestampComment } from '../api/types';
import { useAccounts } from '../hooks/useAccounts';
import { useServer } from '../hooks/useServer';
import { api } from '../api/client';
import * as localDb from '../db/local';

interface MovieDetailSheetProps {
  movie: Movie;
  onClose: () => void;
  onPlay: () => void;
  isFavorited: boolean;
  onToggleFavorite: () => void;
  progress?: number;
}

function formatDuration(seconds?: number): string {
  if (!seconds) return '--';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

function formatFileSize(bytes?: number): string {
  if (!bytes) return '--';
  if (bytes >= 1e9) return `${(bytes / 1e9).toFixed(1)} GB`;
  if (bytes >= 1e6) return `${(bytes / 1e6).toFixed(1)} MB`;
  return `${(bytes / 1e3).toFixed(0)} KB`;
}

function formatTimestamp(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function DetailInfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex">
      <span className="text-gray-500 text-[12px] w-[90px] shrink-0">{label}</span>
      <span className="text-white/90 text-[12px] font-medium">{value}</span>
    </div>
  );
}

export default function MovieDetailSheet({
  movie,
  onClose,
  onPlay,
  isFavorited,
  onToggleFavorite,
  progress,
}: MovieDetailSheetProps) {
  const { isOnline } = useServer();
  const { currentAccount } = useAccounts();
  const [comments, setComments] = useState<TimestampComment[]>([]);
  const [newComment, setNewComment] = useState('');
  const [newTimestamp, setNewTimestamp] = useState('');
  const [isWatched, setIsWatched] = useState(false);

  useEffect(() => {
    loadComments();
  }, [movie.id]);

  const loadComments = async () => {
    try {
      if (isOnline) {
        const data = await api.getComments(movie.id);
        setComments(data);
      } else {
        const data = await localDb.getComments(movie.id);
        setComments(data);
      }
    } catch {
      setComments([]);
    }
  };

  const handleAddComment = async () => {
    if (!newComment.trim() || !currentAccount) return;
    const parts = newTimestamp.split(':').map(Number);
    let seconds = 0;
    if (parts.length === 3) seconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
    else if (parts.length === 2) seconds = parts[0] * 60 + parts[1];
    else seconds = parts[0] || 0;

    try {
      if (isOnline) {
        await api.addComment(currentAccount.id, movie.id, seconds, newComment);
      } else {
        await localDb.addComment(currentAccount.id, movie.id, seconds, newComment);
      }
      setNewComment('');
      setNewTimestamp('');
      await loadComments();
    } catch {}
  };

  const handleMarkWatched = async () => {
    if (!currentAccount) return;
    const newState = !isWatched;
    setIsWatched(newState);
    try {
      if (isOnline) {
        await api.markWatched(currentAccount.id, movie.id, newState);
      } else {
        await localDb.updateProgress(currentAccount.id, movie.id, newState ? 1 : 0, newState);
      }
    } catch {}
  };

  const hue = movie.title.split('').reduce((a, c) => a + c.charCodeAt(0), 0) % 360;
  const isResuming = progress != null && progress > 0 && progress < 1;

  return (
    <motion.div
      className="fixed inset-0 z-50 flex items-center justify-center"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.25 }}
    >
      {/* Backdrop */}
      <motion.div
        className="absolute inset-0 bg-black/80 backdrop-blur-md"
        onClick={onClose}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
      />

      {/* Sheet — matching macOS 860x720 proportions */}
      <motion.div
        className="relative w-[860px] max-h-[720px] overflow-hidden border border-white/[0.06] shadow-2xl shadow-black/60"
        style={{ backgroundColor: 'rgb(15, 15, 15)', borderRadius: '16px' }}
        initial={{ scale: 0.92, opacity: 0, y: 40 }}
        animate={{ scale: 1, opacity: 1, y: 0 }}
        exit={{ scale: 0.92, opacity: 0, y: 40 }}
        transition={{ type: 'spring', stiffness: 350, damping: 30 }}
      >
        {/* ─── Header image / video preview area ─── */}
        <div className="relative h-[380px] overflow-hidden">
          {movie.thumbnail_path ? (
            <img
              src={movie.thumbnail_path}
              alt={movie.title}
              className="w-full h-full object-cover"
            />
          ) : (
            <div
              className="w-full h-full flex items-center justify-center"
              style={{
                background: `linear-gradient(135deg, hsl(${hue}, 40%, 12%), hsl(${(hue + 60) % 360}, 50%, 22%))`,
              }}
            >
              <svg className="w-16 h-16 text-white/10" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
                <path d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
              </svg>
            </div>
          )}

          {/* Multi-layer gradient overlays */}
          <div className="absolute inset-0 bg-gradient-to-t from-[rgb(15,15,15)] via-[rgb(15,15,15)]/30 to-transparent" />
          <div className="absolute inset-0 bg-gradient-to-r from-[rgb(15,15,15)]/40 to-transparent" />

          {/* Close button — matching macOS ultraThinMaterial circle */}
          <button
            onClick={onClose}
            className="absolute top-3 right-3 w-8 h-8 rounded-full bg-black/50 backdrop-blur-sm hover:bg-black/70
                       flex items-center justify-center transition-all duration-200 hover:scale-105"
          >
            <svg className="w-[13px] h-[13px] text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          {/* Title overlay at bottom left — matching macOS positioning */}
          <div className="absolute bottom-3 left-6 right-20">
            <h2
              className="text-[28px] font-bold text-white leading-tight"
              style={{ textShadow: '0 2px 8px rgba(0,0,0,0.8)' }}
            >
              {movie.title}
            </h2>
          </div>

          {/* Mute button placeholder area (right side) */}
        </div>

        {/* ─── Scrollable info section ─── */}
        <div className="overflow-y-auto" style={{ maxHeight: 'calc(720px - 380px)' }}>
          <div className="px-6 py-5 space-y-4">
            {/* Metadata row: year, genre, rating, duration, quality */}
            <div className="flex items-center gap-2.5 flex-wrap text-[13px]">
              {movie.year && (
                <span className="text-white/80">{movie.year}</span>
              )}
              {movie.genre && (
                <span className="px-2 py-0.5 bg-white/10 rounded text-white/80 text-[13px]">
                  {movie.genre}
                </span>
              )}
              {movie.rating != null && (
                <span className="flex items-center gap-1">
                  <span className="text-[12px]">&#127813;</span>
                  <span className={`font-bold ${movie.rating >= 6 ? 'text-green-400' : 'text-gray-400'}`}>
                    {Math.round(movie.rating * 10)}%
                  </span>
                </span>
              )}
              {movie.duration != null && movie.duration > 0 && (
                <span className="text-white/60">{formatDuration(movie.duration)}</span>
              )}
              {movie.quality && (
                <span className="text-white/70 text-[11px] font-medium px-1.5 py-0.5 border border-white/30 rounded">
                  {movie.quality}
                </span>
              )}
            </div>

            {/* Watch status / progress — matching macOS */}
            {isWatched && (
              <div className="flex items-center gap-1.5 text-[12px] font-medium text-green-400">
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
                </svg>
                Watched
              </div>
            )}
            {!isWatched && progress != null && progress > 0 && progress < 1 && (
              <div className="space-y-1">
                <div className="h-1 bg-white/15 rounded-full overflow-hidden">
                  <motion.div
                    className="h-full rounded-full bg-red-500"
                    initial={{ width: 0 }}
                    animate={{ width: `${progress * 100}%` }}
                    transition={{ duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
                  />
                </div>
                <span className="text-white/50 text-[11px]">{Math.round(progress * 100)}% watched</span>
              </div>
            )}

            {/* Action buttons row — matching macOS layout: Play (full-width), Watched, Favorite */}
            <div className="flex items-center gap-2.5">
              <motion.button
                onClick={() => { onPlay(); onClose(); }}
                className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-md
                           text-black text-[15px] font-semibold bg-white hover:bg-gray-100
                           transition-all duration-200"
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.97 }}
              >
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z" />
                </svg>
                {isResuming ? 'Resume' : 'Play'}
              </motion.button>

              <motion.button
                onClick={handleMarkWatched}
                className={`w-11 h-10 rounded-md flex items-center justify-center transition-all duration-200
                            ${isWatched
                              ? 'bg-white/12 text-green-400'
                              : 'bg-white/12 text-white hover:text-green-400'
                            }`}
                whileTap={{ scale: 0.9 }}
              >
                <svg className="w-4 h-4" fill={isWatched ? 'currentColor' : 'none'} viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  <path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                </svg>
              </motion.button>

              <motion.button
                onClick={onToggleFavorite}
                className={`w-11 h-10 rounded-md flex items-center justify-center transition-all duration-200
                            ${isFavorited
                              ? 'bg-white/12 text-red-500'
                              : 'bg-white/12 text-white hover:text-red-400'
                            }`}
                whileTap={{ scale: 0.9 }}
              >
                <motion.svg
                  className="w-4 h-4"
                  fill={isFavorited ? 'currentColor' : 'none'}
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={2}
                  animate={isFavorited ? { scale: [1, 1.3, 1] } : {}}
                  transition={{ duration: 0.3 }}
                >
                  <path strokeLinecap="round" strokeLinejoin="round" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                </motion.svg>
              </motion.button>
            </div>

            {/* Description */}
            {movie.description && (
              <p className="text-white/80 text-[13px] leading-[1.6]">{movie.description}</p>
            )}

            {/* Divider */}
            <div className="h-px bg-gray-700/20" />

            {/* Detail info rows — matching macOS DetailInfoRow */}
            <div className="space-y-1.5">
              {movie.format && (
                <DetailInfoRow label="Format" value={`${movie.format}${movie.file_size ? ` · ${formatFileSize(movie.file_size)}` : ''}`} />
              )}
              {!movie.format && movie.file_size && (
                <DetailInfoRow label="Size" value={formatFileSize(movie.file_size)} />
              )}
              {movie.date_added && (
                <DetailInfoRow label="Added" value={new Date(movie.date_added).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })} />
              )}
            </div>

            {/* Divider */}
            <div className="h-px bg-gray-700/20" />

            {/* Timestamp comments section */}
            <div>
              <h3 className="text-white text-sm font-semibold mb-3">Timestamp Comments</h3>

              {/* Add comment form */}
              <div className="flex gap-2 mb-4">
                <input
                  type="text"
                  value={newTimestamp}
                  onChange={(e) => setNewTimestamp(e.target.value)}
                  placeholder="0:00"
                  className="w-20 bg-cinema-bg/50 border border-cinema-border rounded-lg px-3 py-2 text-white text-xs font-mono
                             focus:outline-none focus:border-cinema-gold/50 focus:ring-1 focus:ring-cinema-gold/20
                             transition-all duration-200 placeholder:text-white/20"
                />
                <input
                  type="text"
                  value={newComment}
                  onChange={(e) => setNewComment(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleAddComment()}
                  placeholder="Add a comment..."
                  className="flex-1 bg-cinema-bg/50 border border-cinema-border rounded-lg px-3 py-2 text-white text-xs
                             focus:outline-none focus:border-cinema-gold/50 focus:ring-1 focus:ring-cinema-gold/20
                             transition-all duration-200 placeholder:text-white/20"
                />
                <motion.button
                  onClick={handleAddComment}
                  className="px-4 py-2 bg-cinema-gold hover:bg-cinema-gold-hover text-black text-xs font-semibold rounded-lg
                             transition-all duration-200"
                  whileTap={{ scale: 0.95 }}
                >
                  Add
                </motion.button>
              </div>

              {/* Comments list */}
              <div className="space-y-2 max-h-40 overflow-y-auto">
                {comments.length === 0 ? (
                  <p className="text-cinema-text-dim text-xs py-2">No comments yet</p>
                ) : (
                  comments.map((c, i) => (
                    <motion.div
                      key={c.id}
                      className="flex gap-3 p-2.5 bg-white/[0.04] rounded-lg hover:bg-white/[0.06] transition-colors duration-150"
                      initial={{ opacity: 0, y: 5 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: i * 0.03, duration: 0.2 }}
                    >
                      <span className="text-cinema-gold text-xs font-mono shrink-0 mt-0.5 tabular-nums">
                        {formatTimestamp(c.timestamp_sec)}
                      </span>
                      <div>
                        <p className="text-white text-xs leading-relaxed">{c.comment}</p>
                        {c.account_name && (
                          <p className="text-cinema-text-dim text-[10px] mt-0.5">{c.account_name}</p>
                        )}
                      </div>
                    </motion.div>
                  ))
                )}
              </div>
            </div>
          </div>
        </div>
      </motion.div>
    </motion.div>
  );
}
