import React from 'react';
import { motion } from 'framer-motion';
import type { Movie } from '../api/types';
import MovieCard from './MovieCard';

interface MovieGridProps {
  title: string;
  movies: Movie[];
  onMovieClick: (movie: Movie) => void;
  onMoviePlay?: (movie: Movie) => void;
  onMovieFavorite?: (movie: Movie) => void;
  favoriteIds?: Set<number>;
  progressMap?: Map<number, number>;
  emptyMessage?: string;
}

const containerVariants = {
  hidden: {},
  visible: {
    transition: {
      staggerChildren: 0.04,
      delayChildren: 0.05,
    },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 20, scale: 0.95 },
  visible: {
    opacity: 1,
    y: 0,
    scale: 1,
    transition: {
      duration: 0.35,
      ease: [0.4, 0, 0.2, 1],
    },
  },
};

export default function MovieGrid({
  title,
  movies,
  onMovieClick,
  onMoviePlay,
  onMovieFavorite,
  favoriteIds,
  progressMap,
  emptyMessage = 'No movies yet',
}: MovieGridProps) {
  return (
    <div>
      <motion.h2
        className="text-white text-xl font-semibold mb-5"
        initial={{ opacity: 0, x: -10 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.3 }}
      >
        {title}
      </motion.h2>
      {movies.length === 0 ? (
        <motion.div
          className="flex flex-col items-center justify-center py-24 text-cinema-text-dim"
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2, duration: 0.4 }}
        >
          <svg className="w-16 h-16 mb-4 opacity-20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
          </svg>
          <p className="text-sm">{emptyMessage}</p>
        </motion.div>
      ) : (
        <motion.div
          className="grid gap-5"
          style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))' }}
          initial="hidden"
          animate="visible"
          variants={containerVariants}
        >
          {movies.map((movie) => (
            <motion.div
              key={movie.id}
              variants={itemVariants}
            >
              <MovieCard
                movie={movie}
                onClick={() => onMovieClick(movie)}
                onPlay={() => onMoviePlay?.(movie)}
                onFavorite={() => onMovieFavorite?.(movie)}
                isFavorited={favoriteIds?.has(movie.id)}
                progress={progressMap?.get(movie.id)}
              />
            </motion.div>
          ))}
        </motion.div>
      )}
    </div>
  );
}
