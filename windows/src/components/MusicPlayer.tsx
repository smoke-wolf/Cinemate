import React, { useRef, useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import type { MusicTrack } from '../api/types';
import { api } from '../api/client';
import { useAccounts } from '../hooks/useAccounts';

export interface MusicPlayerState {
  currentTrack: MusicTrack | null;
  queue: MusicTrack[];
  queueIndex: number;
  isPlaying: boolean;
  playTrack: (track: MusicTrack, queue?: MusicTrack[]) => void;
  togglePlayPause: () => void;
  playNext: () => void;
  playPrev: () => void;
  setQueue: (tracks: MusicTrack[], startIndex?: number) => void;
  clearPlayer: () => void;
}

interface MusicPlayerProps {
  currentTrack: MusicTrack | null;
  queue: MusicTrack[];
  queueIndex: number;
  isPlaying: boolean;
  onPlayPause: () => void;
  onNext: () => void;
  onPrev: () => void;
  onTrackEnd: () => void;
  onTimeUpdate: (currentTime: number, duration: number) => void;
  audioRef: React.RefObject<HTMLAudioElement | null>;
  showQueue: boolean;
  onToggleQueue: () => void;
}

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export default function MusicPlayer({
  currentTrack,
  queue,
  queueIndex,
  isPlaying,
  onPlayPause,
  onNext,
  onPrev,
  onTrackEnd,
  onTimeUpdate,
  audioRef,
  showQueue,
  onToggleQueue,
}: MusicPlayerProps) {
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(0.8);
  const [isMuted, setIsMuted] = useState(false);
  const [isSeeking, setIsSeeking] = useState(false);
  const seekRef = useRef<HTMLDivElement>(null);

  const { currentAccount } = useAccounts();

  // Sync audio state
  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    const handleTimeUpdate = () => {
      if (!isSeeking) {
        setCurrentTime(audio.currentTime);
        setDuration(audio.duration || 0);
        onTimeUpdate(audio.currentTime, audio.duration || 0);
      }
    };

    const handleLoadedMetadata = () => {
      setDuration(audio.duration || 0);
    };

    const handleEnded = () => {
      // Log play
      if (currentAccount && currentTrack) {
        api.logMusicPlay(currentAccount.id, currentTrack.id, audio.currentTime).catch(() => {});
      }
      onTrackEnd();
    };

    audio.addEventListener('timeupdate', handleTimeUpdate);
    audio.addEventListener('loadedmetadata', handleLoadedMetadata);
    audio.addEventListener('ended', handleEnded);

    return () => {
      audio.removeEventListener('timeupdate', handleTimeUpdate);
      audio.removeEventListener('loadedmetadata', handleLoadedMetadata);
      audio.removeEventListener('ended', handleEnded);
    };
  }, [audioRef, isSeeking, onTrackEnd, onTimeUpdate, currentAccount, currentTrack]);

  // Volume sync
  useEffect(() => {
    const audio = audioRef.current;
    if (audio) {
      audio.volume = isMuted ? 0 : volume;
    }
  }, [volume, isMuted, audioRef]);

  const handleSeekStart = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    setIsSeeking(true);
    const rect = seekRef.current?.getBoundingClientRect();
    if (!rect || !duration) return;
    const pct = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    setCurrentTime(pct * duration);
  }, [duration]);

  const handleSeekMove = useCallback((e: MouseEvent) => {
    if (!isSeeking) return;
    const rect = seekRef.current?.getBoundingClientRect();
    if (!rect || !duration) return;
    const pct = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    setCurrentTime(pct * duration);
  }, [isSeeking, duration]);

  const handleSeekEnd = useCallback(() => {
    if (!isSeeking) return;
    setIsSeeking(false);
    const audio = audioRef.current;
    if (audio) {
      audio.currentTime = currentTime;
    }
  }, [isSeeking, currentTime, audioRef]);

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

  if (!currentTrack) return null;

  const progressPct = duration > 0 ? (currentTime / duration) * 100 : 0;
  const albumArtUrl = currentTrack.album_id ? api.getMusicArtUrl(currentTrack.album_id) : null;

  return (
    <>
      {/* Queue panel */}
      <AnimatePresence>
        {showQueue && (
          <motion.div
            className="fixed right-0 bottom-[72px] w-[340px] max-h-[60vh] bg-cinema-card/95 backdrop-blur-xl
                       border border-cinema-border rounded-tl-2xl shadow-2xl shadow-black/60 z-40 overflow-hidden flex flex-col"
            initial={{ opacity: 0, y: 20, x: 20 }}
            animate={{ opacity: 1, y: 0, x: 0 }}
            exit={{ opacity: 0, y: 20, x: 20 }}
            transition={{ duration: 0.25, ease: [0.4, 0, 0.2, 1] }}
          >
            <div className="px-4 py-3 border-b border-cinema-border flex items-center justify-between">
              <h3 className="text-white text-sm font-semibold">Queue</h3>
              <span className="text-cinema-text-dim text-xs">{queue.length} tracks</span>
            </div>
            <div className="flex-1 overflow-y-auto">
              {queue.map((track, i) => (
                <div
                  key={`${track.id}-${i}`}
                  className={`flex items-center gap-3 px-4 py-2.5 cursor-pointer transition-all duration-150
                             hover:bg-white/[0.04]
                             ${i === queueIndex ? 'bg-cinema-gold/10' : ''}`}
                >
                  <span className={`text-xs w-5 text-right tabular-nums font-mono
                                   ${i === queueIndex ? 'text-cinema-gold' : 'text-cinema-text-dim'}`}>
                    {i === queueIndex ? (
                      <svg className="w-3.5 h-3.5 text-cinema-gold" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M8 5v14l11-7z" />
                      </svg>
                    ) : (
                      i + 1
                    )}
                  </span>
                  <div className="flex-1 min-w-0">
                    <p className={`text-sm truncate ${i === queueIndex ? 'text-cinema-gold font-medium' : 'text-white'}`}>
                      {track.title}
                    </p>
                    <p className="text-cinema-text-dim text-xs truncate">{track.artist}</p>
                  </div>
                  <span className="text-cinema-text-dim text-xs tabular-nums">
                    {formatDuration(track.duration)}
                  </span>
                </div>
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Player bar */}
      <motion.div
        className="fixed bottom-0 left-0 right-0 h-[72px] bg-cinema-sidebar/95 backdrop-blur-xl
                   border-t border-cinema-border z-40 flex items-center px-4 gap-4"
        initial={{ y: 72 }}
        animate={{ y: 0 }}
        exit={{ y: 72 }}
        transition={{ type: 'spring', stiffness: 350, damping: 30 }}
      >
        {/* Progress bar (top of player bar) */}
        <div
          ref={seekRef}
          className="absolute top-0 left-0 right-0 h-1 bg-white/[0.06] cursor-pointer group/seek"
          onMouseDown={handleSeekStart}
        >
          <div
            className="h-full progress-bar-gold transition-[width] duration-100 relative"
            style={{ width: `${progressPct}%` }}
          >
            <div className="absolute right-0 top-1/2 -translate-y-1/2 w-3 h-3 rounded-full bg-cinema-gold
                            opacity-0 group-hover/seek:opacity-100 transition-opacity duration-150
                            shadow-sm shadow-cinema-gold/40"
                 style={{ transform: 'translate(50%, -50%)' }} />
          </div>
        </div>

        {/* Track info */}
        <div className="flex items-center gap-3 w-[260px] min-w-0">
          {/* Album art */}
          <div className="w-12 h-12 rounded-lg overflow-hidden bg-cinema-surface flex-shrink-0
                          ring-1 ring-white/[0.06]">
            {albumArtUrl ? (
              <img src={albumArtUrl} alt={currentTrack.album} className="w-full h-full object-cover" />
            ) : (
              <div className="w-full h-full flex items-center justify-center">
                <svg className="w-6 h-6 text-cinema-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                </svg>
              </div>
            )}
          </div>
          <div className="min-w-0">
            <p className="text-white text-sm font-medium truncate">{currentTrack.title}</p>
            <p className="text-cinema-text-dim text-xs truncate">{currentTrack.artist}</p>
          </div>
        </div>

        {/* Controls (centered) */}
        <div className="flex-1 flex items-center justify-center gap-5">
          {/* Prev */}
          <motion.button
            onClick={onPrev}
            className="text-cinema-text-secondary hover:text-white transition-colors duration-150"
            whileHover={{ scale: 1.1 }}
            whileTap={{ scale: 0.9 }}
          >
            <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M6 6h2v12H6zm3.5 6l8.5 6V6z" />
            </svg>
          </motion.button>

          {/* Play / Pause */}
          <motion.button
            onClick={onPlayPause}
            className="w-10 h-10 rounded-full bg-cinema-gold flex items-center justify-center
                       hover:bg-cinema-gold-hover transition-colors duration-150"
            whileHover={{ scale: 1.08 }}
            whileTap={{ scale: 0.92 }}
            style={{ boxShadow: '0 2px 12px rgba(212, 160, 23, 0.3)' }}
          >
            {isPlaying ? (
              <svg className="w-5 h-5 text-black" fill="currentColor" viewBox="0 0 24 24">
                <path d="M6 4h4v16H6zM14 4h4v16h-4z" />
              </svg>
            ) : (
              <svg className="w-5 h-5 text-black ml-0.5" fill="currentColor" viewBox="0 0 24 24">
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
            <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z" />
            </svg>
          </motion.button>
        </div>

        {/* Right side: time + volume + queue */}
        <div className="flex items-center gap-4 w-[260px] justify-end">
          {/* Time */}
          <span className="text-cinema-text-dim text-xs font-mono tabular-nums whitespace-nowrap">
            {formatDuration(currentTime)} / {formatDuration(duration || currentTrack.duration)}
          </span>

          {/* Volume */}
          <div className="flex items-center gap-2 group/vol">
            <motion.button
              onClick={() => setIsMuted(!isMuted)}
              className="text-cinema-text-secondary hover:text-white transition-colors duration-150"
              whileTap={{ scale: 0.9 }}
            >
              {isMuted || volume === 0 ? (
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />
                </svg>
              ) : (
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                </svg>
              )}
            </motion.button>
            <input
              type="range"
              min={0}
              max={1}
              step={0.01}
              value={isMuted ? 0 : volume}
              onChange={(e) => {
                const v = parseFloat(e.target.value);
                setVolume(v);
                setIsMuted(v === 0);
              }}
              className="w-20 h-1 rounded-full appearance-none cursor-pointer
                         [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-3 [&::-webkit-slider-thumb]:h-3
                         [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-white
                         [&::-webkit-slider-thumb]:hover:scale-125 [&::-webkit-slider-thumb]:transition-transform"
              style={{
                background: `linear-gradient(to right, #d4a017 ${(isMuted ? 0 : volume) * 100}%, rgba(255,255,255,0.15) ${(isMuted ? 0 : volume) * 100}%)`,
              }}
            />
          </div>

          {/* Queue toggle */}
          <motion.button
            onClick={onToggleQueue}
            className={`transition-colors duration-150 ${showQueue ? 'text-cinema-gold' : 'text-cinema-text-secondary hover:text-white'}`}
            whileHover={{ scale: 1.1 }}
            whileTap={{ scale: 0.9 }}
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 10h16M4 14h10M4 18h7" />
            </svg>
          </motion.button>
        </div>
      </motion.div>
    </>
  );
}
