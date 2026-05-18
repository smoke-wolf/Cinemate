import React, { useRef, useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import type { Movie, TimestampComment } from '../api/types';
import { useAccounts } from '../hooks/useAccounts';
import { useServer } from '../hooks/useServer';
import { api } from '../api/client';
import * as localDb from '../db/local';

interface VideoPlayerProps {
  movie: Movie;
  onClose: () => void;
  initialProgress?: number;
}

function formatTime(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export default function VideoPlayer({ movie, onClose, initialProgress }: VideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const hideTimeout = useRef<ReturnType<typeof setTimeout>>();
  const saveInterval = useRef<ReturnType<typeof setInterval>>();

  const { currentAccount } = useAccounts();
  const { isOnline } = useServer();

  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(1);
  const [isMuted, setIsMuted] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [showControls, setShowControls] = useState(true);
  const [comments, setComments] = useState<TimestampComment[]>([]);
  const [hoveredComment, setHoveredComment] = useState<TimestampComment | null>(null);

  // Load comments
  useEffect(() => {
    const load = async () => {
      try {
        if (isOnline) {
          setComments(await api.getComments(movie.id));
        } else {
          setComments(await localDb.getComments(movie.id));
        }
      } catch {}
    };
    load();
  }, [movie.id, isOnline]);

  // Set initial progress
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    const handleLoadedMetadata = () => {
      setDuration(video.duration);
      if (initialProgress && initialProgress > 0 && initialProgress < 1) {
        video.currentTime = video.duration * initialProgress;
      }
    };

    video.addEventListener('loadedmetadata', handleLoadedMetadata);
    return () => video.removeEventListener('loadedmetadata', handleLoadedMetadata);
  }, [initialProgress]);

  const currentTimeRef = useRef(currentTime);
  const durationRef = useRef(duration);
  currentTimeRef.current = currentTime;
  durationRef.current = duration;

  const saveProgress = useCallback(async () => {
    if (!currentAccount || !durationRef.current) return;
    const positionSec = currentTimeRef.current;
    const durationSec = durationRef.current;
    const progress = positionSec / durationSec;
    const completed = progress > 0.9;
    try {
      if (isOnline) {
        await api.updateProgress(currentAccount.id, movie.id, positionSec, durationSec);
      } else {
        await localDb.updateProgress(currentAccount.id, movie.id, progress, completed);
      }
    } catch {}
  }, [currentAccount, movie.id, isOnline]);

  // Save progress periodically
  useEffect(() => {
    saveInterval.current = setInterval(() => {
      saveProgress();
    }, 10000);
    return () => {
      if (saveInterval.current) clearInterval(saveInterval.current);
      saveProgress();
    };
  }, [saveProgress]);

  // Auto-hide controls
  const resetHideTimer = useCallback(() => {
    setShowControls(true);
    if (hideTimeout.current) clearTimeout(hideTimeout.current);
    if (isPlaying) {
      hideTimeout.current = setTimeout(() => setShowControls(false), 3000);
    }
  }, [isPlaying]);

  const togglePlay = () => {
    const video = videoRef.current;
    if (!video) return;
    if (video.paused) {
      video.play();
      setIsPlaying(true);
    } else {
      video.pause();
      setIsPlaying(false);
    }
  };

  const handleSeek = (e: React.ChangeEvent<HTMLInputElement>) => {
    const video = videoRef.current;
    if (!video) return;
    const time = parseFloat(e.target.value);
    video.currentTime = time;
    setCurrentTime(time);
  };

  const handleVolumeChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const vol = parseFloat(e.target.value);
    setVolume(vol);
    if (videoRef.current) {
      videoRef.current.volume = vol;
      setIsMuted(vol === 0);
    }
  };

  const toggleMute = () => {
    if (videoRef.current) {
      videoRef.current.muted = !isMuted;
      setIsMuted(!isMuted);
    }
  };

  const toggleFullscreen = async () => {
    const container = containerRef.current;
    if (!container) return;
    if (!document.fullscreenElement) {
      await container.requestFullscreen();
      setIsFullscreen(true);
    } else {
      await document.exitFullscreen();
      setIsFullscreen(false);
    }
  };

  const handleClose = () => {
    saveProgress();
    onClose();
  };

  // Skip forward/backward
  const skip = (seconds: number) => {
    const video = videoRef.current;
    if (!video) return;
    video.currentTime = Math.max(0, Math.min(video.duration, video.currentTime + seconds));
  };

  // Get video source URL
  const videoSrc = movie.file_path.startsWith('http')
    ? movie.file_path
    : `file://${movie.file_path}`;

  const progressPercent = duration > 0 ? (currentTime / duration) * 100 : 0;

  return (
    <motion.div
      ref={containerRef}
      className="fixed inset-0 z-50 bg-black flex items-center justify-center cursor-none"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.3 }}
      onMouseMove={resetHideTimer}
      onClick={togglePlay}
      style={{ cursor: showControls ? 'default' : 'none' }}
    >
      {/* Video element */}
      <video
        ref={videoRef}
        src={videoSrc}
        className="w-full h-full object-contain"
        onTimeUpdate={() => {
          if (videoRef.current) setCurrentTime(videoRef.current.currentTime);
        }}
        onEnded={() => setIsPlaying(false)}
        onPlay={() => setIsPlaying(true)}
        onPause={() => setIsPlaying(false)}
      />

      {/* Center play/pause flash indicator */}
      <AnimatePresence>
        {!isPlaying && showControls && (
          <motion.div
            className="absolute inset-0 flex items-center justify-center pointer-events-none"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.15 }}
          >
            <div className="w-20 h-20 rounded-full bg-black/40 backdrop-blur-sm flex items-center justify-center">
              <svg className="w-10 h-10 text-white ml-1" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z" />
              </svg>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Controls overlay */}
      <AnimatePresence>
        {showControls && (
          <motion.div
            className="absolute inset-0 flex flex-col justify-between pointer-events-none"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.25 }}
          >
            {/* Top bar */}
            <div className="px-6 py-4 bg-gradient-to-b from-black/70 via-black/30 to-transparent pointer-events-auto">
              <div className="flex items-center gap-4">
                <motion.button
                  onClick={(e) => { e.stopPropagation(); handleClose(); }}
                  className="w-9 h-9 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center transition-all duration-200"
                  whileHover={{ scale: 1.1 }}
                  whileTap={{ scale: 0.9 }}
                >
                  <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                  </svg>
                </motion.button>
                <div>
                  <h3 className="text-white font-semibold text-sm text-shadow">{movie.title}</h3>
                  {movie.year && <span className="text-white/60 text-xs">{movie.year}</span>}
                </div>
              </div>
            </div>

            {/* Center spacer */}
            <div className="flex-1" />

            {/* Bottom controls */}
            <div className="px-6 pb-6 pt-16 bg-gradient-to-t from-black/80 via-black/40 to-transparent pointer-events-auto"
                 onClick={(e) => e.stopPropagation()}>
              {/* Seek bar with comment markers */}
              <div className="relative mb-4 group/seek">
                {/* Comment markers */}
                {duration > 0 && comments.map((c) => {
                  const leftPct = (c.timestamp_sec / duration) * 100;
                  return (
                    <div
                      key={c.id}
                      className="absolute -top-1 w-2.5 h-2.5 bg-cinema-gold rounded-full z-10 cursor-pointer
                                 hover:scale-150 transition-transform duration-150
                                 shadow-sm shadow-cinema-gold/40"
                      style={{ left: `${leftPct}%`, transform: 'translateX(-50%)' }}
                      onMouseEnter={() => setHoveredComment(c)}
                      onMouseLeave={() => setHoveredComment(null)}
                    />
                  );
                })}

                {/* Hovered comment tooltip */}
                <AnimatePresence>
                  {hoveredComment && (
                    <motion.div
                      className="absolute -top-10 bg-cinema-card/95 backdrop-blur-sm text-white text-xs px-3 py-1.5 rounded-lg
                                 border border-cinema-border shadow-lg z-20 whitespace-nowrap max-w-[200px] truncate"
                      style={{ left: `${(hoveredComment.timestamp_sec / duration) * 100}%`, transform: 'translateX(-50%)' }}
                      initial={{ opacity: 0, y: 5 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: 5 }}
                      transition={{ duration: 0.15 }}
                    >
                      <span className="text-cinema-gold font-mono mr-1.5">{formatTime(hoveredComment.timestamp_sec)}</span>
                      {hoveredComment.comment}
                    </motion.div>
                  )}
                </AnimatePresence>

                <input
                  type="range"
                  min={0}
                  max={duration || 0}
                  value={currentTime}
                  onChange={handleSeek}
                  className="seek-bar"
                  style={{
                    background: `linear-gradient(to right, #d4a017 ${progressPercent}%, rgba(255,255,255,0.15) ${progressPercent}%)`,
                  }}
                />
              </div>

              {/* Control buttons */}
              <div className="flex items-center gap-4">
                {/* Play/Pause */}
                <motion.button
                  onClick={togglePlay}
                  className="text-white hover:text-cinema-gold transition-colors duration-150"
                  whileHover={{ scale: 1.1 }}
                  whileTap={{ scale: 0.9 }}
                >
                  {isPlaying ? (
                    <svg className="w-7 h-7" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M6 4h4v16H6zM14 4h4v16h-4z" />
                    </svg>
                  ) : (
                    <svg className="w-7 h-7" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M8 5v14l11-7z" />
                    </svg>
                  )}
                </motion.button>

                {/* Skip backward 10s */}
                <motion.button
                  onClick={() => skip(-10)}
                  className="text-white/70 hover:text-white transition-colors duration-150"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.9 }}
                >
                  <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12.066 11.2a1 1 0 000 1.6l5.334 4A1 1 0 0019 16V8a1 1 0 00-1.6-.8l-5.333 4zM4.066 11.2a1 1 0 000 1.6l5.334 4A1 1 0 0011 16V8a1 1 0 00-1.6-.8l-5.334 4z" />
                  </svg>
                </motion.button>

                {/* Skip forward 10s */}
                <motion.button
                  onClick={() => skip(10)}
                  className="text-white/70 hover:text-white transition-colors duration-150"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.9 }}
                >
                  <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11.933 12.8a1 1 0 000-1.6L6.6 7.2A1 1 0 005 8v8a1 1 0 001.6.8l5.333-4zM19.933 12.8a1 1 0 000-1.6l-5.333-4A1 1 0 0013 8v8a1 1 0 001.6.8l5.333-4z" />
                  </svg>
                </motion.button>

                {/* Volume */}
                <div className="flex items-center gap-2 group/vol">
                  <motion.button
                    onClick={toggleMute}
                    className="text-white hover:text-cinema-gold transition-colors duration-150"
                    whileTap={{ scale: 0.9 }}
                  >
                    {isMuted || volume === 0 ? (
                      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />
                      </svg>
                    ) : (
                      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                      </svg>
                    )}
                  </motion.button>
                  <div className="w-0 group-hover/vol:w-20 overflow-hidden transition-all duration-250">
                    <input
                      type="range"
                      min={0}
                      max={1}
                      step={0.01}
                      value={isMuted ? 0 : volume}
                      onChange={handleVolumeChange}
                      className="w-20 h-1 rounded-full appearance-none cursor-pointer
                                 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-3 [&::-webkit-slider-thumb]:h-3
                                 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-white
                                 [&::-webkit-slider-thumb]:hover:scale-125 [&::-webkit-slider-thumb]:transition-transform"
                      style={{
                        background: `linear-gradient(to right, #fff ${(isMuted ? 0 : volume) * 100}%, rgba(255,255,255,0.2) ${(isMuted ? 0 : volume) * 100}%)`,
                      }}
                    />
                  </div>
                </div>

                {/* Time display */}
                <span className="text-white/70 text-xs font-mono tabular-nums">
                  {formatTime(currentTime)} / {formatTime(duration)}
                </span>

                <div className="flex-1" />

                {/* Fullscreen */}
                <motion.button
                  onClick={toggleFullscreen}
                  className="text-white hover:text-cinema-gold transition-colors duration-150"
                  whileHover={{ scale: 1.1 }}
                  whileTap={{ scale: 0.9 }}
                >
                  {isFullscreen ? (
                    <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 9V4.5M9 9H4.5M9 9L3.75 3.75M9 15v4.5M9 15H4.5M9 15l-5.25 5.25M15 9h4.5M15 9V4.5M15 9l5.25-5.25M15 15h4.5M15 15v4.5m0-4.5l5.25 5.25" />
                    </svg>
                  ) : (
                    <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M3.75 20.25v-4.5m0 4.5h4.5m-4.5 0L9 15M20.25 3.75h-4.5m4.5 0v4.5m0-4.5L15 9m5.25 11.25h-4.5m4.5 0v-4.5m0 4.5L15 15" />
                    </svg>
                  )}
                </motion.button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}
