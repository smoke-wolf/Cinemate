import React, { useState, useEffect, useRef, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import type { MusicTrack } from '../api/types';
import { api } from '../api/client';

interface NowPlayingBarProps {
  currentTrack: MusicTrack;
  isPlaying: boolean;
  onPlayPause: () => void;
  onNext: () => void;
  onPrev: () => void;
  audioRef: React.RefObject<HTMLAudioElement | null>;
  onExpandClick: () => void;
}

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export default function NowPlayingBar({
  currentTrack,
  isPlaying,
  onPlayPause,
  onNext,
  onPrev,
  audioRef,
  onExpandClick,
}: NowPlayingBarProps) {
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [isSeeking, setIsSeeking] = useState(false);
  const [isHovered, setIsHovered] = useState(false);
  const seekRef = useRef<HTMLDivElement>(null);
  const seekTimeRef = useRef(0);

  // Sync audio state
  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    const handleTimeUpdate = () => {
      if (!isSeeking) {
        setCurrentTime(audio.currentTime);
        setDuration(audio.duration || 0);
      }
    };

    const handleLoadedMetadata = () => {
      setDuration(audio.duration || 0);
    };

    audio.addEventListener('timeupdate', handleTimeUpdate);
    audio.addEventListener('loadedmetadata', handleLoadedMetadata);

    return () => {
      audio.removeEventListener('timeupdate', handleTimeUpdate);
      audio.removeEventListener('loadedmetadata', handleLoadedMetadata);
    };
  }, [audioRef, isSeeking]);

  const handleSeekStart = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    e.stopPropagation();
    setIsSeeking(true);
    const rect = seekRef.current?.getBoundingClientRect();
    if (!rect || !duration) return;
    const pct = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    const time = pct * duration;
    seekTimeRef.current = time;
    setCurrentTime(time);
  }, [duration]);

  const handleSeekMove = useCallback((e: MouseEvent) => {
    if (!isSeeking) return;
    const rect = seekRef.current?.getBoundingClientRect();
    if (!rect || !duration) return;
    const pct = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    const time = pct * duration;
    seekTimeRef.current = time;
    setCurrentTime(time);
  }, [isSeeking, duration]);

  const handleSeekEnd = useCallback(() => {
    if (!isSeeking) return;
    setIsSeeking(false);
    const audio = audioRef.current;
    if (audio) {
      audio.currentTime = seekTimeRef.current;
    }
  }, [isSeeking, audioRef]);

  useEffect(() => {
    if (isSeeking) {
      window.addEventListener('mousemove', handleSeekMove);
      window.addEventListener('mouseup', handleSeekEnd);
      return () => {
        window.removeEventListener('mousemove', handleSeekMove);
        window.removeEventListener('mouseup', handleSeekEnd);
      };
    }
  }, [isSeeking, handleSeekMove, handleSeekEnd]);

  const progressPct = duration > 0 ? (currentTime / duration) * 100 : 0;
  const albumArtUrl = currentTrack.album_id ? api.getMusicArtUrl(currentTrack.album_id) : null;

  return (
    <motion.div
      className="fixed bottom-0 left-0 right-0 z-30"
      initial={{ y: 64 }}
      animate={{ y: 0 }}
      exit={{ y: 64 }}
      transition={{ type: 'spring', stiffness: 400, damping: 35 }}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      {/* Top border line */}
      <div className="h-px bg-white/[0.08]" />

      <div className="h-16 bg-cinema-sidebar/95 backdrop-blur-xl flex items-center px-4 gap-3 relative">
        {/* Progress bar at top */}
        <div
          ref={seekRef}
          className="absolute top-0 left-0 right-0 h-1 bg-white/[0.06] cursor-pointer group/seek"
          onMouseDown={handleSeekStart}
        >
          <div
            className="h-full bg-cinema-gold/80 transition-[width] duration-100 relative"
            style={{ width: `${progressPct}%` }}
          >
            <AnimatePresence>
              {isHovered && (
                <motion.div
                  className="absolute right-0 top-1/2 w-2.5 h-2.5 rounded-full bg-cinema-gold shadow-sm shadow-cinema-gold/40"
                  style={{ transform: 'translate(50%, -50%)' }}
                  initial={{ scale: 0, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  exit={{ scale: 0, opacity: 0 }}
                  transition={{ duration: 0.15 }}
                />
              )}
            </AnimatePresence>
          </div>
        </div>

        {/* Album art + track info (clickable to expand) */}
        <div
          className="flex items-center gap-3 min-w-0 flex-shrink-0 cursor-pointer group/info"
          onClick={onExpandClick}
        >
          <div className="w-10 h-10 rounded-md overflow-hidden bg-cinema-surface flex-shrink-0
                          ring-1 ring-white/[0.06] group-hover/info:ring-cinema-gold/30 transition-all duration-200">
            {albumArtUrl ? (
              <img src={albumArtUrl} alt={currentTrack.album} className="w-full h-full object-cover" />
            ) : (
              <div className="w-full h-full flex items-center justify-center">
                <svg className="w-5 h-5 text-cinema-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5}
                        d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                </svg>
              </div>
            )}
          </div>
          <div className="min-w-0">
            <p className="text-white text-sm font-medium truncate max-w-[180px]
                          group-hover/info:text-cinema-gold transition-colors duration-150">
              {currentTrack.title}
            </p>
            <p className="text-cinema-text-dim text-xs truncate max-w-[180px]">
              {currentTrack.artist}
            </p>
          </div>
        </div>

        {/* Centered controls */}
        <div className="flex-1 flex items-center justify-center gap-4">
          {/* Previous */}
          <motion.button
            onClick={onPrev}
            className="text-cinema-text-secondary hover:text-white transition-colors duration-150"
            whileHover={{ scale: 1.1 }}
            whileTap={{ scale: 0.9 }}
          >
            <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
              <path d="M6 6h2v12H6zm3.5 6l8.5 6V6z" />
            </svg>
          </motion.button>

          {/* Play / Pause */}
          <motion.button
            onClick={onPlayPause}
            className="w-8 h-8 rounded-full bg-cinema-gold flex items-center justify-center
                       hover:bg-cinema-gold-hover transition-colors duration-150"
            whileHover={{ scale: 1.08 }}
            whileTap={{ scale: 0.92 }}
            style={{ boxShadow: '0 2px 8px rgba(212, 160, 23, 0.25)' }}
          >
            {isPlaying ? (
              <svg className="w-4 h-4 text-black" fill="currentColor" viewBox="0 0 24 24">
                <path d="M6 4h4v16H6zM14 4h4v16h-4z" />
              </svg>
            ) : (
              <svg className="w-4 h-4 text-black ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z" />
              </svg>
            )}
          </motion.button>

          {/* Next */}
          <motion.button
            onClick={onNext}
            className="text-cinema-text-secondary hover:text-white transition-colors duration-150"
            whileHover={{ scale: 1.1 }}
            whileTap={{ scale: 0.9 }}
          >
            <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
              <path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z" />
            </svg>
          </motion.button>
        </div>

        {/* Right side: time */}
        <div className="flex items-center gap-3 flex-shrink-0">
          <span className="text-cinema-text-dim text-xs font-mono tabular-nums whitespace-nowrap">
            {formatDuration(currentTime)} / {formatDuration(duration || currentTrack.duration)}
          </span>

          {/* Expand button */}
          <motion.button
            onClick={onExpandClick}
            className="text-cinema-text-secondary hover:text-cinema-gold transition-colors duration-150"
            whileHover={{ scale: 1.1 }}
            whileTap={{ scale: 0.9 }}
            title="Open full player"
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                    d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
            </svg>
          </motion.button>
        </div>
      </div>
    </motion.div>
  );
}
