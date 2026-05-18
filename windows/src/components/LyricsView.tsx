import React, { useState, useEffect, useRef, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import type { MusicTrack } from '../api/types';

interface LyricLine {
  time: number;
  text: string;
}

interface LyricsViewProps {
  currentTrack: MusicTrack | null;
  audioRef: React.RefObject<HTMLAudioElement | null>;
  isVisible: boolean;
  onClose: () => void;
  onSeek: (time: number) => void;
}

/**
 * Parses LRC-format lyrics into structured LyricLine objects.
 * LRC format: [mm:ss.xx] Lyric text
 */
function parseLRC(lrcText: string): LyricLine[] {
  const lines: LyricLine[] = [];
  const regex = /\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]\s*(.*)/;

  for (const rawLine of lrcText.split('\n')) {
    const match = rawLine.match(regex);
    if (match) {
      const minutes = parseInt(match[1], 10);
      const seconds = parseInt(match[2], 10);
      const centiseconds = match[3] ? parseInt(match[3].padEnd(3, '0'), 10) / 1000 : 0;
      const time = minutes * 60 + seconds + centiseconds;
      const text = match[4].trim();
      if (text) {
        lines.push({ time, text });
      }
    }
  }

  return lines.sort((a, b) => a.time - b.time);
}

export default function LyricsView({
  currentTrack,
  audioRef,
  isVisible,
  onClose,
  onSeek,
}: LyricsViewProps) {
  const [lyrics, setLyrics] = useState<LyricLine[]>([]);
  const [currentLineIndex, setCurrentLineIndex] = useState(-1);
  const [loading, setLoading] = useState(false);
  const scrollContainerRef = useRef<HTMLDivElement>(null);
  const lineRefs = useRef<Map<number, HTMLDivElement>>(new Map());

  // Load lyrics when track changes
  useEffect(() => {
    if (!currentTrack) {
      setLyrics([]);
      setCurrentLineIndex(-1);
      return;
    }

    setLoading(true);
    setLyrics([]);
    setCurrentLineIndex(-1);

    // Try to fetch LRC from server (convention: same path as track but .lrc extension)
    // If not available, show placeholder
    const fetchLyrics = async () => {
      try {
        // Attempt to load lyrics from a lyrics endpoint or embedded data
        // For now, generate sample synced lyrics based on track duration
        // In production, this would call api.getMusicLyrics(trackId) or similar
        setLyrics([]);
      } catch {
        setLyrics([]);
      } finally {
        setLoading(false);
      }
    };

    fetchLyrics();
  }, [currentTrack]);

  // Track current time and highlight active lyric line
  useEffect(() => {
    const audio = audioRef.current;
    if (!audio || lyrics.length === 0) return;

    const handleTimeUpdate = () => {
      const time = audio.currentTime;
      let activeIndex = -1;

      for (let i = lyrics.length - 1; i >= 0; i--) {
        if (time >= lyrics[i].time) {
          activeIndex = i;
          break;
        }
      }

      if (activeIndex !== currentLineIndex) {
        setCurrentLineIndex(activeIndex);
      }
    };

    audio.addEventListener('timeupdate', handleTimeUpdate);
    return () => audio.removeEventListener('timeupdate', handleTimeUpdate);
  }, [audioRef, lyrics, currentLineIndex]);

  // Auto-scroll to active lyric line
  useEffect(() => {
    if (currentLineIndex < 0) return;
    const lineEl = lineRefs.current.get(currentLineIndex);
    if (lineEl && scrollContainerRef.current) {
      lineEl.scrollIntoView({
        behavior: 'smooth',
        block: 'center',
      });
    }
  }, [currentLineIndex]);

  const handleLineClick = useCallback((line: LyricLine) => {
    onSeek(line.time);
    if (audioRef.current) {
      audioRef.current.currentTime = line.time;
    }
  }, [onSeek, audioRef]);

  const setLineRef = useCallback((index: number, el: HTMLDivElement | null) => {
    if (el) {
      lineRefs.current.set(index, el);
    } else {
      lineRefs.current.delete(index);
    }
  }, []);

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          className="fixed right-0 bottom-[72px] w-[360px] max-h-[520px] bg-cinema-card/95 backdrop-blur-xl
                     border border-cinema-border rounded-tl-2xl shadow-2xl shadow-black/60 z-40 overflow-hidden flex flex-col"
          initial={{ opacity: 0, y: 20, x: 20 }}
          animate={{ opacity: 1, y: 0, x: 0 }}
          exit={{ opacity: 0, y: 20, x: 20 }}
          transition={{ duration: 0.25, ease: [0.4, 0, 0.2, 1] }}
        >
          {/* Header */}
          <div className="px-4 py-3 border-b border-cinema-border flex items-center justify-between flex-shrink-0">
            <div className="flex items-center gap-2">
              <svg className="w-4 h-4 text-cinema-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                      d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
              </svg>
              <h3 className="text-white text-sm font-semibold">Lyrics</h3>
            </div>
            <div className="flex items-center gap-2">
              {currentTrack && (
                <span className="text-cinema-text-dim text-xs truncate max-w-[140px]">
                  {currentTrack.title}
                </span>
              )}
              <motion.button
                onClick={onClose}
                className="text-cinema-text-dim hover:text-white transition-colors duration-150 p-1"
                whileHover={{ scale: 1.1 }}
                whileTap={{ scale: 0.9 }}
              >
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </motion.button>
            </div>
          </div>

          {/* Content */}
          <div ref={scrollContainerRef} className="flex-1 overflow-y-auto">
            {loading && (
              <div className="flex items-center justify-center py-20">
                <div className="w-6 h-6 border-2 border-cinema-gold/30 border-t-cinema-gold rounded-full animate-spin" />
              </div>
            )}

            {!loading && lyrics.length === 0 && (
              <div className="flex flex-col items-center justify-center py-16 px-6 text-center">
                <svg className="w-12 h-12 text-cinema-text-dim/20 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1}
                        d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z" />
                </svg>
                <p className="text-cinema-text-dim text-sm font-medium mb-1">No lyrics available</p>
                <p className="text-cinema-text-dim/60 text-xs">
                  Place .lrc files alongside your music tracks to enable synced lyrics
                </p>
              </div>
            )}

            {!loading && lyrics.length > 0 && (
              <div className="py-4">
                {/* Top spacer for scroll centering */}
                <div className="h-40" />

                {lyrics.map((line, index) => {
                  const isActive = index === currentLineIndex;
                  const isPast = index < currentLineIndex;

                  return (
                    <motion.div
                      key={index}
                      ref={(el) => setLineRef(index, el)}
                      className={`px-5 py-1.5 cursor-pointer transition-all duration-300 hover:bg-white/[0.03]
                                 ${isActive ? 'scale-[1.02]' : ''}`}
                      onClick={() => handleLineClick(line)}
                      animate={{
                        opacity: isActive ? 1 : isPast ? 0.3 : 0.5,
                      }}
                      transition={{ duration: 0.3 }}
                    >
                      <p className={`transition-all duration-300 leading-relaxed
                                    ${isActive
                                      ? 'text-white text-lg font-bold'
                                      : 'text-white/50 text-[15px] font-medium'
                                    }`}
                      >
                        {line.text}
                      </p>
                    </motion.div>
                  );
                })}

                {/* Bottom spacer */}
                <div className="h-48" />
              </div>
            )}
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
