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
      <div className="w-full h-full flex items-center justify-center">
        <svg className="w-12 h-12 text-white/15" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
        </svg>
      </div>
    </div>
  );
}

export default function MovieCard({ movie, onClick, onPlay, onFavorite, isFavorited, progress }: MovieCardProps) {
  const [imgLoaded, setImgLoaded] = useState(false);

  const handleImgLoad = useCallback(() => setImgLoaded(true), []);

  return (
    <motion.div
      className="relative group cursor-pointer flex-shrink-0 w-[180px]"
      whileHover={{ scale: 1.05, y: -6 }}
      transition={{ duration: 0.25, ease: [0.4, 0, 0.2, 1] }}
      onClick={onClick}
    >
      {/* Thumbnail */}
      <div className="relative w-[180px] h-[270px] rounded-xl overflow-hidden bg-cinema-card
                      ring-1 ring-white/[0.04] group-hover:ring-white/[0.08]
                      transition-all duration-300
                      group-hover:shadow-xl group-hover:shadow-black/50">
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

        {/* Hover overlay — gradient for text readability */}
        <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/0 to-black/0
                        opacity-0 group-hover:opacity-100 transition-opacity duration-250" />

        {/* Play button */}
        <div className="absolute inset-0 flex items-center justify-center">
          <motion.button
            className="opacity-0 group-hover:opacity-100 transition-all duration-250
                       w-14 h-14 bg-cinema-gold/95 rounded-full flex items-center justify-center
                       hover:bg-cinema-gold shadow-lg shadow-black/30
                       backdrop-blur-sm"
            onClick={(e) => { e.stopPropagation(); onPlay?.(); }}
            whileHover={{ scale: 1.12 }}
            whileTap={{ scale: 0.9 }}
            style={{ boxShadow: '0 4px 20px rgba(212, 160, 23, 0.35)' }}
          >
            <svg className="w-6 h-6 text-black ml-0.5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M8 5v14l11-7z" />
            </svg>
          </motion.button>
        </div>

        {/* Favorite heart */}
        <button
          onClick={(e) => { e.stopPropagation(); onFavorite?.(); }}
          className="absolute top-2.5 right-2.5 opacity-0 group-hover:opacity-100 transition-all duration-250
                     w-8 h-8 rounded-full bg-black/40 backdrop-blur-sm flex items-center justify-center
                     hover:bg-black/60 hover:scale-110"
        >
          <svg
            className={`w-4 h-4 transition-all duration-200 ${isFavorited ? 'text-cinema-red fill-current scale-110' : 'text-white'}`}
            fill={isFavorited ? 'currentColor' : 'none'}
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
          </svg>
        </button>

        {/* Quality badge */}
        {movie.quality && (
          <div className={`absolute top-2.5 left-2.5 px-2 py-0.5 rounded-md text-[10px] font-bold text-white
                          backdrop-blur-sm ${getQualityBadgeClass(movie.quality)}`}>
            {getQualityLabel(movie.quality)}
          </div>
        )}

        {/* Progress bar */}
        {progress != null && progress > 0 && progress < 1 && (
          <div className="absolute bottom-0 left-0 right-0 h-[3px] bg-black/40">
            <motion.div
              className="h-full progress-bar-gold"
              initial={{ width: 0 }}
              animate={{ width: `${progress * 100}%` }}
              transition={{ duration: 0.4, ease: 'easeOut' }}
            />
          </div>
        )}
      </div>

      {/* Info */}
      <div className="mt-2.5 px-1">
        <h3 className="text-white text-sm font-medium truncate group-hover:text-cinema-gold transition-colors duration-200">
          {movie.title}
        </h3>
        <div className="flex items-center gap-2 mt-0.5">
          {movie.year && (
            <span className="text-cinema-text-dim text-xs">{movie.year}</span>
          )}
        </div>
      </div>
    </motion.div>
  );
}
