import React, { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import type { Movie, TimestampComment } from '../api/types';
import { useLibrary } from '../hooks/useLibrary';
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

      {/* Sheet */}
      <motion.div
        className="relative w-[700px] max-h-[85vh] bg-cinema-card rounded-2xl overflow-hidden
                   border border-white/[0.06] shadow-2xl shadow-black/60"
        initial={{ scale: 0.92, opacity: 0, y: 40 }}
        animate={{ scale: 1, opacity: 1, y: 0 }}
        exit={{ scale: 0.92, opacity: 0, y: 40 }}
        transition={{ type: 'spring', stiffness: 350, damping: 30 }}
      >
        {/* Header image */}
        <div className="relative h-[280px] overflow-hidden">
          {movie.thumbnail_path ? (
            <img
              src={movie.thumbnail_path}
              alt={movie.title}
              className="w-full h-full object-cover"
            />
          ) : (
            <div
              className="w-full h-full"
              style={{
                background: `linear-gradient(135deg, hsl(${hue}, 40%, 12%), hsl(${(hue + 60) % 360}, 50%, 22%))`,
              }}
            />
          )}
          {/* Multi-layer gradient for depth */}
          <div className="absolute inset-0 bg-gradient-to-t from-cinema-card via-cinema-card/30 to-transparent" />
          <div className="absolute inset-0 bg-gradient-to-r from-cinema-card/40 to-transparent" />

          {/* Close button */}
          <button
            onClick={onClose}
            className="absolute top-4 right-4 w-9 h-9 rounded-full bg-black/40 backdrop-blur-sm hover:bg-black/60
                       flex items-center justify-center transition-all duration-200 hover:scale-105"
          >
            <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          {/* Play button overlay */}
          <motion.button
            onClick={onPlay}
            className="absolute bottom-6 left-6 flex items-center gap-3 px-7 py-3.5 bg-cinema-gold
                       hover:bg-cinema-gold-hover text-black font-bold rounded-full
                       transition-all duration-200"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            style={{ boxShadow: '0 4px 20px rgba(212, 160, 23, 0.35)' }}
          >
            <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M8 5v14l11-7z" />
            </svg>
            {progress && progress > 0 && progress < 1 ? 'Resume' : 'Play'}
          </motion.button>
        </div>

        {/* Content */}
        <div className="p-6 overflow-y-auto max-h-[calc(85vh-280px)]">
          {/* Title row */}
          <div className="flex items-start justify-between mb-4">
            <div>
              <h2 className="text-2xl font-bold text-white mb-1">{movie.title}</h2>
              <div className="flex items-center gap-3 text-cinema-text-secondary text-sm">
                {movie.year && <span>{movie.year}</span>}
                {movie.genre && (
                  <>
                    <span className="w-1 h-1 rounded-full bg-cinema-text-dim" />
                    <span>{movie.genre}</span>
                  </>
                )}
                {movie.format && (
                  <>
                    <span className="w-1 h-1 rounded-full bg-cinema-text-dim" />
                    <span className="uppercase text-xs font-medium">{movie.format}</span>
                  </>
                )}
              </div>
            </div>
            <div className="flex items-center gap-2">
              {/* Favorite */}
              <motion.button
                onClick={onToggleFavorite}
                className="w-10 h-10 rounded-full bg-cinema-surface hover:bg-cinema-border flex items-center justify-center
                           transition-all duration-200"
                whileTap={{ scale: 0.9 }}
              >
                <motion.svg
                  className={`w-5 h-5 ${isFavorited ? 'text-cinema-red' : 'text-cinema-text-secondary'}`}
                  fill={isFavorited ? 'currentColor' : 'none'}
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  animate={isFavorited ? { scale: [1, 1.3, 1] } : {}}
                  transition={{ duration: 0.3 }}
                >
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                </motion.svg>
              </motion.button>
              {/* Mark watched */}
              <motion.button
                onClick={handleMarkWatched}
                className={`w-10 h-10 rounded-full flex items-center justify-center transition-all duration-200
                            ${isWatched ? 'bg-cinema-green/20 text-cinema-green' : 'bg-cinema-surface text-cinema-text-secondary hover:bg-cinema-border'}`}
                whileTap={{ scale: 0.9 }}
              >
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
              </motion.button>
            </div>
          </div>

          {/* Stats row */}
          <div className="flex items-center gap-4 mb-5">
            {movie.rating != null && (
              <div className="flex items-center gap-1.5">
                <svg className="w-4 h-4 text-cinema-gold" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
                <span className="text-white text-sm font-medium">{movie.rating.toFixed(1)}</span>
                <span className="text-cinema-text-dim text-xs">({Math.round(movie.rating * 10)}%)</span>
              </div>
            )}
            {movie.quality && (
              <span className={`px-2 py-0.5 rounded-md text-[10px] font-bold text-white ${
                movie.quality.toLowerCase().includes('4k') || movie.quality === '2160p' ? 'badge-4k' :
                movie.quality === '1080p' ? 'badge-1080p' :
                movie.quality === '720p' ? 'badge-720p' : 'bg-cinema-surface'
              }`}>
                {movie.quality}
              </span>
            )}
            <span className="text-cinema-text-secondary text-sm">{formatDuration(movie.duration)}</span>
            <span className="text-cinema-text-secondary text-sm">{formatFileSize(movie.file_size)}</span>
          </div>

          {/* Progress bar */}
          {progress != null && progress > 0 && progress < 1 && (
            <div className="mb-5">
              <div className="flex justify-between text-xs text-cinema-text-dim mb-1.5">
                <span>Watch Progress</span>
                <span className="tabular-nums">{Math.round(progress * 100)}%</span>
              </div>
              <div className="h-1.5 bg-cinema-surface rounded-full overflow-hidden">
                <motion.div
                  className="h-full progress-bar-gold rounded-full"
                  initial={{ width: 0 }}
                  animate={{ width: `${progress * 100}%` }}
                  transition={{ duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
                />
              </div>
            </div>
          )}

          {/* Description */}
          {movie.description && (
            <p className="text-cinema-text-secondary text-sm leading-relaxed mb-6">{movie.description}</p>
          )}

          {/* Timestamp comments */}
          <div className="border-t border-cinema-border pt-5">
            <h3 className="text-white text-sm font-semibold mb-3">Timestamp Comments</h3>

            {/* Add comment */}
            <div className="flex gap-2 mb-4">
              <input
                type="text"
                value={newTimestamp}
                onChange={(e) => setNewTimestamp(e.target.value)}
                placeholder="0:00"
                className="w-20 bg-cinema-bg/50 border border-cinema-border rounded-lg px-3 py-2 text-white text-xs font-mono
                           focus:outline-none focus:border-cinema-gold/50 focus:ring-1 focus:ring-cinema-gold/20
                           transition-all duration-200"
              />
              <input
                type="text"
                value={newComment}
                onChange={(e) => setNewComment(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleAddComment()}
                placeholder="Add a comment..."
                className="flex-1 bg-cinema-bg/50 border border-cinema-border rounded-lg px-3 py-2 text-white text-xs
                           focus:outline-none focus:border-cinema-gold/50 focus:ring-1 focus:ring-cinema-gold/20
                           transition-all duration-200"
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
                    className="flex gap-3 p-2.5 bg-cinema-surface/80 rounded-lg hover:bg-cinema-surface transition-colors duration-150"
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
      </motion.div>
    </motion.div>
  );
}
