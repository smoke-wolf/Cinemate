import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import type { TVShow, TVSeason } from '../api/types';
import { useLibrary } from '../hooks/useLibrary';

function GradientPlaceholder({ title }: { title: string }) {
  const hue = title.split('').reduce((a, c) => a + c.charCodeAt(0), 0) % 360;
  return (
    <div
      className="w-full h-full rounded-xl"
      style={{
        background: `linear-gradient(135deg, hsl(${hue}, 40%, 12%), hsl(${(hue + 60) % 360}, 50%, 22%))`,
      }}
    />
  );
}

interface ShowCardProps {
  show: TVShow;
  onClick: () => void;
  index: number;
}

function ShowCard({ show, onClick, index }: ShowCardProps) {
  return (
    <motion.div
      className="group cursor-pointer"
      initial={{ opacity: 0, y: 20, scale: 0.95 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{ delay: index * 0.04, duration: 0.35, ease: [0.4, 0, 0.2, 1] }}
      whileHover={{ scale: 1.03, y: -4 }}
      onClick={onClick}
    >
      <div className="relative w-full aspect-video rounded-xl overflow-hidden bg-cinema-card mb-2.5
                      ring-1 ring-white/[0.04] group-hover:ring-white/[0.08]
                      group-hover:shadow-xl group-hover:shadow-black/40
                      transition-all duration-300">
        {show.thumbnail_path ? (
          <img src={show.thumbnail_path} alt={show.name} className="w-full h-full object-cover" />
        ) : (
          <GradientPlaceholder title={show.name} />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent
                        opacity-0 group-hover:opacity-100 transition-opacity duration-250" />
        <div className="absolute inset-0 flex items-center justify-center">
          <motion.div
            className="opacity-0 group-hover:opacity-100 transition-opacity duration-250"
            whileHover={{ scale: 1.1 }}
          >
            <div className="w-14 h-14 rounded-full bg-cinema-gold/90 backdrop-blur-sm flex items-center justify-center
                            shadow-lg"
                 style={{ boxShadow: '0 4px 20px rgba(212, 160, 23, 0.35)' }}>
              <svg className="w-6 h-6 text-black ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z" />
              </svg>
            </div>
          </motion.div>
        </div>
        {/* Episode count badge */}
        <div className="absolute bottom-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity duration-250">
          <span className="px-2 py-1 bg-black/60 backdrop-blur-sm rounded-md text-[10px] font-semibold text-white/90">
            {show.episode_count || 0} eps
          </span>
        </div>
      </div>
      <h3 className="text-white text-sm font-medium truncate group-hover:text-cinema-gold transition-colors duration-200">
        {show.name}
      </h3>
      <div className="flex items-center gap-2 mt-0.5">
        <span className="text-cinema-text-dim text-xs">{show.episode_count || 0} episodes</span>
        {show.watched_count != null && show.watched_count > 0 && (
          <>
            <span className="w-1 h-1 rounded-full bg-cinema-text-dim" />
            <span className="text-cinema-green text-xs">{show.watched_count} watched</span>
          </>
        )}
      </div>
    </motion.div>
  );
}

export default function TVShowsView() {
  const { tvShows } = useLibrary();
  const [selectedShow, setSelectedShow] = useState<TVShow | null>(null);
  const [expandedSeason, setExpandedSeason] = useState<number | null>(null);

  if (tvShows.length === 0) {
    return (
      <motion.div
        className="flex flex-col items-center justify-center h-full text-cinema-text-dim"
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
      >
        <svg className="w-20 h-20 mb-4 opacity-15" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
        </svg>
        <p className="text-lg font-medium mb-1">No TV Shows</p>
        <p className="text-sm">Scan a folder containing TV show files to get started</p>
      </motion.div>
    );
  }

  return (
    <div className="h-full overflow-y-auto p-6">
      <motion.h2
        className="text-white text-xl font-semibold mb-6"
        initial={{ opacity: 0, x: -10 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.3 }}
      >
        TV Shows
      </motion.h2>

      {/* Show grid */}
      <div className="grid grid-cols-3 gap-5 xl:grid-cols-4">
        {tvShows.map((show, i) => (
          <ShowCard
            key={show.id}
            show={show}
            index={i}
            onClick={() => {
              setSelectedShow(show);
              if (show.seasons && show.seasons.length > 0) {
                setExpandedSeason(show.seasons[0].season);
              }
            }}
          />
        ))}
      </div>

      {/* Show detail / episode list */}
      <AnimatePresence>
        {selectedShow && (
          <motion.div
            className="fixed inset-0 z-50 flex items-center justify-center"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.25 }}
          >
            <motion.div
              className="absolute inset-0 bg-black/80 backdrop-blur-md"
              onClick={() => setSelectedShow(null)}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
            />
            <motion.div
              className="relative w-[600px] max-h-[80vh] bg-cinema-card rounded-2xl overflow-hidden
                         border border-white/[0.06] shadow-2xl shadow-black/60"
              initial={{ scale: 0.92, opacity: 0, y: 30 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.92, opacity: 0, y: 30 }}
              transition={{ type: 'spring', stiffness: 350, damping: 30 }}
            >
              {/* Header */}
              <div className="p-6 border-b border-cinema-border">
                <div className="flex items-start justify-between">
                  <div>
                    <h3 className="text-xl font-bold text-white">{selectedShow.name}</h3>
                    {selectedShow.genre && (
                      <p className="text-cinema-text-secondary text-sm mt-1">{selectedShow.genre}</p>
                    )}
                    <p className="text-cinema-text-dim text-xs mt-1.5">
                      {selectedShow.episode_count} episodes
                      {selectedShow.seasons && ` across ${selectedShow.seasons.length} seasons`}
                    </p>
                  </div>
                  <motion.button
                    onClick={() => setSelectedShow(null)}
                    className="w-9 h-9 rounded-full bg-cinema-surface hover:bg-cinema-border flex items-center justify-center
                               transition-all duration-200"
                    whileHover={{ scale: 1.1 }}
                    whileTap={{ scale: 0.9 }}
                  >
                    <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </motion.button>
                </div>
                {selectedShow.description && (
                  <p className="text-cinema-text-secondary text-sm mt-3 leading-relaxed">{selectedShow.description}</p>
                )}
              </div>

              {/* Seasons and episodes */}
              <div className="p-4 overflow-y-auto max-h-[50vh]">
                {selectedShow.seasons?.map((season, si) => (
                  <motion.div
                    key={season.season}
                    className="mb-2"
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: si * 0.05, duration: 0.2 }}
                  >
                    <button
                      onClick={() => setExpandedSeason(expandedSeason === season.season ? null : season.season)}
                      className={`w-full flex items-center justify-between px-4 py-3 rounded-lg
                                 transition-all duration-200
                                 ${expandedSeason === season.season
                                   ? 'bg-cinema-gold/10 border border-cinema-gold/20'
                                   : 'bg-cinema-surface hover:bg-cinema-border border border-transparent'
                                 }`}
                    >
                      <span className={`text-sm font-medium transition-colors duration-200
                                       ${expandedSeason === season.season ? 'text-cinema-gold' : 'text-white'}`}>
                        Season {season.season}
                      </span>
                      <div className="flex items-center gap-2">
                        <span className="text-cinema-text-dim text-xs">{season.episodes.length} episodes</span>
                        <motion.svg
                          className="w-4 h-4 text-cinema-text-dim"
                          fill="none" viewBox="0 0 24 24" stroke="currentColor"
                          animate={{ rotate: expandedSeason === season.season ? 180 : 0 }}
                          transition={{ duration: 0.25 }}
                        >
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                        </motion.svg>
                      </div>
                    </button>

                    <AnimatePresence>
                      {expandedSeason === season.season && (
                        <motion.div
                          initial={{ height: 0, opacity: 0 }}
                          animate={{ height: 'auto', opacity: 1 }}
                          exit={{ height: 0, opacity: 0 }}
                          transition={{ duration: 0.25, ease: [0.4, 0, 0.2, 1] }}
                          className="overflow-hidden"
                        >
                          <div className="pl-4 py-2 space-y-0.5">
                            {season.episodes.map((ep, ei) => (
                              <motion.div
                                key={ep.id}
                                className="flex items-center gap-3 px-3 py-2.5 rounded-lg
                                           hover:bg-cinema-surface/70 transition-all duration-150 cursor-pointer group"
                                initial={{ opacity: 0, x: -8 }}
                                animate={{ opacity: 1, x: 0 }}
                                transition={{ delay: ei * 0.02, duration: 0.2 }}
                              >
                                <span className="text-cinema-text-dim text-xs w-6 text-right tabular-nums font-mono">
                                  {ep.episode}
                                </span>
                                <div className="flex-1 min-w-0">
                                  <p className="text-white text-sm truncate group-hover:text-cinema-gold transition-colors duration-150">
                                    {ep.title || `Episode ${ep.episode}`}
                                  </p>
                                </div>
                                <motion.svg
                                  className="w-5 h-5 text-cinema-gold opacity-0 group-hover:opacity-100 transition-opacity duration-150"
                                  fill="currentColor" viewBox="0 0 24 24"
                                  whileHover={{ scale: 1.2 }}
                                >
                                  <path d="M8 5v14l11-7z" />
                                </motion.svg>
                              </motion.div>
                            ))}
                          </div>
                        </motion.div>
                      )}
                    </AnimatePresence>
                  </motion.div>
                )) || (
                  <p className="text-cinema-text-dim text-sm text-center py-8">No seasons loaded</p>
                )}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
