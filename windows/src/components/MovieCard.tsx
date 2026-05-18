import React, { useState, useCallback } from 'react';
import { motion } from 'framer-motion';
import type { Movie } from '../api/types';

interface MovieCardProps {
  movie: Movie;
  onClick: () => void;
  onPlay?: () => void;
  onFavorite?: () => void;
  isFavorited?: boolean;
  progress?: number;
}

function getQualityBadgeClass(quality?: string): string {
  switch (quality?.toLowerCase()) {
    case '4k':
    case '2160p':
      return 'badge-4k';
    case '1080p':
      return 'badge-1080p';
    case '720p':
      return 'badge-720p';
    default:
      return 'bg-cinema-surface';
  }
}

function getQualityLabel(quality?: string): string {
  switch (quality?.toLowerCase()) {
    case '4k':
    case '2160p':
      return '4K';
    case '1080p':
      return '1080p';
    case '720p':
      return '720p';
    default:
      return quality || '';
  }
}

function GradientPlaceholder({ title }: { title: string }) {
  const hue = title.split('').reduce((a, c) => a + c.charCodeAt(0), 0) % 360;
  return (
    <div
      className="w-full h-full"
      style={{
        background: `linear-gradient(135deg, hsl(${hue}, 40%, 12%), hsl(${(hue + 60) % 360}, 50%, 22%))`,
      }}
    >
      <div className="w-full h-full flex items-center justify-center flex-col gap-2">
        <svg className="w-7 h-7 text-white/15" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
          <path d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
        </svg>
        <span className="text-white/15 text-[10px]">{title.split('.').pop()}</span>
      </div>
    </div>
  );
}

export default function MovieCard({ movie, onClick, onPlay, onFavorite, isFavorited, progress }: MovieCardProps) {
  const [imgLoaded, setImgLoaded] = useState(false);
  const [isHovered, setIsHovered] = useState(false);

  const handleImgLoad = useCallback(() => setImgLoaded(true), []);

  const formatDuration = (seconds?: number) => {
    if (!seconds) return '';
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    if (h > 0) return `${h}h ${m}m`;
    return `${m}m`;
  };

  return (
    <motion.div
      className="relative group cursor-pointer flex-shrink-0 w-[180px]"
      onHoverStart={() => setIsHovered(true)}
      onHoverEnd={() => setIsHovered(false)}
      animate={{
        scale: isHovered ? 1.05 : 1,
        y: isHovered ? -6 : 0,
      }}
      transition={{ duration: 0.15, ease: [0.4, 0, 0.2, 1] }}
      onClick={onClick}
    >
      {/* Thumbnail container — 16:9 aspect matching macOS MovieCard */}
      <div
        className="relative w-[180px] h-[101px] overflow-hidden bg-cinema-card transition-all duration-200"
        style={{
          borderRadius: '8px',
          boxShadow: isHovered
            ? '0 8px 30px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,255,255,0.08)'
            : '0 1px 3px rgba(0,0,0,0.3), 0 0 0 1px rgba(255,255,255,0.04)',
        }}
      >
        {movie.thumbnail_path ? (
          <>
            {!imgLoaded && (
              <div className="absolute inset-0 shimmer bg-cinema-card" />
            )}
            <img
              src={movie.thumbnail_path}
              alt={movie.title}
              className={`w-full h-full object-cover transition-opacity duration-300 ${imgLoaded ? 'opacity-100' : 'opacity-0'}`}
              loading="lazy"
              onLoad={handleImgLoad}
            />
          </>
        ) : (
          <GradientPlaceholder title={movie.title} />
        )}

        {/* Hover overlay — dark scrim with play button + controls */}
        <motion.div
          className="absolute inset-0 flex flex-col items-center justify-center"
          initial={false}
          animate={{ opacity: isHovered ? 1 : 0 }}
          transition={{ duration: 0.15 }}
          style={{ background: 'rgba(0,0,0,0.45)' }}
        >
          <motion.button
            className="w-10 h-10 rounded-full bg-white/90 flex items-center justify-center
                       hover:bg-white shadow-lg shadow-black/30"
            onClick={(e) => { e.stopPropagation(); onPlay?.(); }}
            whileHover={{ scale: 1.12 }}
            whileTap={{ scale: 0.9 }}
          >
            <svg className="w-5 h-5 text-black ml-0.5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M8 5v14l11-7z" />
            </svg>
          </motion.button>

          {/* Bottom row: favorite, duration, quality */}
          <div className="absolute bottom-1.5 left-0 right-0 flex items-center justify-center gap-3">
            <button
              onClick={(e) => { e.stopPropagation(); onFavorite?.(); }}
              className="hover:scale-110 transition-transform"
            >
              <svg
                className={`w-4 h-4 transition-colors duration-200 ${isFavorited ? 'text-red-500' : 'text-white'}`}
                fill={isFavorited ? 'currentColor' : 'none'}
                viewBox="0 0 24 24"
                stroke="currentColor"
                strokeWidth={2}
              >
                <path strokeLinecap="round" strokeLinejoin="round" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
              </svg>
            </button>
            {movie.duration != null && movie.duration > 0 && (
              <span className="text-white/70 text-[11px]">{formatDuration(movie.duration)}</span>
            )}
            {movie.quality && (
              <span className="text-white/60 text-[10px] font-medium">{movie.quality}</span>
            )}
          </div>
        </motion.div>

        {/* Top-right badges: rating + watched check (always visible) */}
        <div className="absolute top-1.5 right-1.5 flex items-center gap-1">
          {movie.rating != null && (
            <span className="flex items-center gap-0.5 px-1.5 py-0.5 bg-black/70 rounded text-[10px] font-bold backdrop-blur-sm">
              <span className="text-[9px]">&#127813;</span>
              <span className={movie.rating >= 6 ? 'text-red-400' : 'text-gray-400'}>{Math.round(movie.rating * 10)}%</span>
            </span>
          )}
        </div>

        {/* Quality badge — top left */}
        {movie.quality && (
          <div className={`absolute top-1.5 left-1.5 px-1.5 py-0.5 rounded text-[10px] font-bold text-white
                          backdrop-blur-sm ${getQualityBadgeClass(movie.quality)}`}>
            {getQualityLabel(movie.quality)}
          </div>
        )}

        {/* Progress bar at bottom — orange, matching macOS */}
        {progress != null && progress > 0 && progress < 1 && (
          <div className="absolute bottom-0 left-0 right-0">
            <div className="h-[3px] bg-transparent">
              <motion.div
                className="h-full bg-orange-500 rounded-b"
                initial={{ width: 0 }}
                animate={{ width: `${progress * 100}%` }}
                transition={{ duration: 0.4, ease: 'easeOut' }}
              />
            </div>
          </div>
        )}
      </div>

      {/* Title and metadata below card */}
      <div className="mt-1.5 px-0.5">
        <h3 className="text-white text-[12px] font-medium leading-tight line-clamp-2">
          {movie.title}
        </h3>
        <div className="flex items-center gap-1.5 mt-0.5 text-[11px]">
          {movie.year && (
            <span className="text-gray-400">{movie.year}</span>
          )}
          {movie.genre && (
            <span className="text-gray-500">{movie.genre}</span>
          )}
          {movie.duration != null && movie.duration > 0 && (
            <span className="text-gray-500">{formatDuration(movie.duration)}</span>
          )}
          {movie.quality && (
            <span className="text-gray-600">{movie.quality}</span>
          )}
        </div>
      </div>
    </motion.div>
  );
}
