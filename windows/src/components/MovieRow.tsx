import React, { useRef, useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import type { Movie } from '../api/types';
import MovieCard from './MovieCard';

interface MovieRowProps {
  title: string;
  movies: Movie[];
  onMovieClick: (movie: Movie) => void;
  onMoviePlay?: (movie: Movie) => void;
  onMovieFavorite?: (movie: Movie) => void;
  favoriteIds?: Set<number>;
  progressMap?: Map<number, number>;
}

export default function MovieRow({
  title,
  movies,
  onMovieClick,
  onMoviePlay,
  onMovieFavorite,
  favoriteIds,
  progressMap,
}: MovieRowProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [canScrollLeft, setCanScrollLeft] = useState(false);
  const [canScrollRight, setCanScrollRight] = useState(true);

  const checkScroll = () => {
    const el = scrollRef.current;
    if (!el) return;
    setCanScrollLeft(el.scrollLeft > 2);
    setCanScrollRight(el.scrollLeft < el.scrollWidth - el.clientWidth - 2);
  };

  useEffect(() => {
    checkScroll();
    const el = scrollRef.current;
    if (el) {
      const observer = new ResizeObserver(checkScroll);
      observer.observe(el);
      return () => observer.disconnect();
    }
  }, [movies.length]);

  if (movies.length === 0) return null;

  const scroll = (direction: 'left' | 'right') => {
    const el = scrollRef.current;
    if (!el) return;
    const amount = el.clientWidth * 0.75;
    el.scrollBy({
      left: direction === 'right' ? amount : -amount,
      behavior: 'smooth',
    });
    setTimeout(checkScroll, 400);
  };

  return (
    <div className="mb-8">
      <h2 className="text-white text-lg font-semibold mb-3 px-1">{title}</h2>
      <div className="relative group/row">
        {/* Left fade + arrow */}
        <AnimatePresence>
          {canScrollLeft && (
            <motion.button
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.2 }}
              onClick={() => scroll('left')}
              className="absolute left-0 top-0 bottom-8 z-10 w-16
                         bg-gradient-to-r from-cinema-bg via-cinema-bg/80 to-transparent
                         flex items-center justify-start pl-2
                         opacity-0 group-hover/row:opacity-100 transition-opacity duration-200"
            >
              <div className="w-8 h-8 rounded-full bg-black/50 backdrop-blur-sm flex items-center justify-center
                              hover:bg-black/70 hover:scale-110 transition-all duration-200">
                <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M15 19l-7-7 7-7" />
                </svg>
              </div>
            </motion.button>
          )}
        </AnimatePresence>

        {/* Scroll container */}
        <div
          ref={scrollRef}
          onScroll={checkScroll}
          className="flex gap-4 overflow-x-auto hide-scrollbar pb-2 px-1
                     scroll-smooth"
        >
          {movies.map((movie) => (
            <MovieCard
              key={movie.id}
              movie={movie}
              onClick={() => onMovieClick(movie)}
              onPlay={() => onMoviePlay?.(movie)}
              onFavorite={() => onMovieFavorite?.(movie)}
              isFavorited={favoriteIds?.has(movie.id)}
              progress={progressMap?.get(movie.id)}
            />
          ))}
        </div>

        {/* Right fade + arrow */}
        <AnimatePresence>
          {canScrollRight && (
            <motion.button
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.2 }}
              onClick={() => scroll('right')}
              className="absolute right-0 top-0 bottom-8 z-10 w-16
                         bg-gradient-to-l from-cinema-bg via-cinema-bg/80 to-transparent
                         flex items-center justify-end pr-2
                         opacity-0 group-hover/row:opacity-100 transition-opacity duration-200"
            >
              <div className="w-8 h-8 rounded-full bg-black/50 backdrop-blur-sm flex items-center justify-center
                              hover:bg-black/70 hover:scale-110 transition-all duration-200">
                <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
                </svg>
              </div>
            </motion.button>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
