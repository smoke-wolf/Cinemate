import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import type { TVShow, TVSeason, TVEpisode } from '../api/types';
import { useLibrary } from '../hooks/useLibrary';

function GradientPlaceholder({ title }: { title: string }) {
  const hue = title.split('').reduce((a, c) => a + c.charCodeAt(0), 0) % 360;
  return (
    <div
      className="w-full h-full"
      style={{
        background: `linear-gradient(135deg, hsl(${hue}, 40%, 12%), hsl(${(hue + 60) % 360}, 50%, 22%))`,
      }}
    >
      <div className="w-full h-full flex flex-col items-center justify-center gap-2">
        <svg className="w-8 h-8 text-white/15" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
          <path d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
        </svg>
      </div>
    </div>
  );
}

function formatDuration(seconds?: number): string {
  if (!seconds) return '';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

function formatFileSize(bytes?: number): string {
  if (!bytes) return '';
  if (bytes >= 1e9) return `${(bytes / 1e9).toFixed(1)} GB`;
  if (bytes >= 1e6) return `${(bytes / 1e6).toFixed(1)} MB`;
  return `${(bytes / 1e3).toFixed(0)} KB`;
}

/* ─── ShowCard — matching macOS ShowCard ─── */

interface ShowCardProps {
  show: TVShow;
  onClick: () => void;
  index: number;
}

function ShowCard({ show, onClick, index }: ShowCardProps) {
  const [isHovered, setIsHovered] = useState(false);

  return (
    <motion.div
      className="group cursor-pointer"
      initial={{ opacity: 0, y: 20, scale: 0.95 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{ delay: index * 0.04, duration: 0.35, ease: [0.4, 0, 0.2, 1] }}
      onHoverStart={() => setIsHovered(true)}
      onHoverEnd={() => setIsHovered(false)}
      onClick={onClick}
    >
      <motion.div
        animate={{ scale: isHovered ? 1.03 : 1, y: isHovered ? -3 : 0 }}
        transition={{ duration: 0.15, ease: [0.4, 0, 0.2, 1] }}
      >
        <div
          className="relative w-full aspect-video overflow-hidden bg-cinema-card mb-2 transition-all duration-200"
          style={{
            borderRadius: '10px',
            boxShadow: isHovered
              ? '0 8px 30px rgba(0,0,0,0.4), 0 0 0 1px rgba(255,255,255,0.08)'
              : '0 1px 3px rgba(0,0,0,0.3), 0 0 0 1px rgba(255,255,255,0.04)',
          }}
        >
          {show.thumbnail_path ? (
            <img src={show.thumbnail_path} alt={show.name} className="w-full h-full object-cover" />
          ) : (
            <GradientPlaceholder title={show.name} />
          )}

          {/* Hover overlay */}
          <motion.div
            className="absolute inset-0 flex items-center justify-center"
            initial={false}
            animate={{ opacity: isHovered ? 1 : 0 }}
            transition={{ duration: 0.15 }}
            style={{ background: 'rgba(0,0,0,0.4)' }}
          >
            <div
              className="w-10 h-10 rounded-full bg-white/90 flex items-center justify-center shadow-lg"
            >
              <svg className="w-5 h-5 text-black ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z" />
              </svg>
            </div>
          </motion.div>

          {/* Watched count badge — bottom left, matching macOS green badge */}
          {show.watched_count != null && show.watched_count > 0 && (
            <div className="absolute bottom-2 left-2 flex items-center gap-1 px-2 py-1 bg-green-500/85 rounded text-[10px] font-semibold text-white">
              <svg className="w-[10px] h-[10px]" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
              </svg>
              {show.watched_count}/{show.episode_count || 0}
            </div>
          )}

          {/* Episode count badge — bottom right, matching macOS */}
          <div className="absolute bottom-2 right-2">
            <span className="text-white/80 text-[11px] font-medium">
              {show.episode_count || 0} eps
            </span>
          </div>
        </div>
      </motion.div>

      {/* Show title */}
      <h3 className="text-white text-[14px] font-semibold truncate leading-tight">
        {show.name}
      </h3>
      {/* Subtitle line */}
      <div className="flex items-center gap-2 mt-0.5 text-[12px] text-gray-400">
        {show.seasons && show.seasons.length > 0 && (
          <span>{show.seasons.length}S {show.episode_count || 0}E</span>
        )}
        {!show.seasons && (
          <span>{show.episode_count || 0} episodes</span>
        )}
      </div>
    </motion.div>
  );
}

/* ─── Season Pill — matching macOS SeasonPill ─── */

function SeasonPill({ label, isSelected, onClick }: { label: string; isSelected: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className={`px-4 py-1.5 rounded-full text-[13px] transition-all duration-200 shrink-0
                 ${isSelected
                   ? 'bg-white text-black font-semibold'
                   : 'bg-white/10 text-white hover:bg-white/15 font-normal'
                 }`}
    >
      {label}
    </button>
  );
}

/* ─── EpisodeRow — matching macOS EpisodeRow with thumbnail ─── */

function EpisodeRow({
  episode,
  onPlay,
  index,
}: {
  episode: TVEpisode;
  onPlay: () => void;
  index: number;
}) {
  const [isHovered, setIsHovered] = useState(false);

  return (
    <motion.div
      className={`flex items-center gap-4 px-3 py-2 rounded-lg cursor-pointer transition-all duration-150
                  ${isHovered ? 'bg-white/[0.04]' : ''}`}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      onClick={onPlay}
      initial={{ opacity: 0, x: -8 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ delay: index * 0.02, duration: 0.2 }}
    >
      {/* Episode thumbnail */}
      <div className="relative w-[160px] h-[90px] rounded-md overflow-hidden bg-cinema-card/60 shrink-0">
        {episode.thumbnail_path ? (
          <img src={episode.thumbnail_path} alt="" className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full flex items-center justify-center">
            <svg className="w-6 h-6 text-white/15" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
              <path d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
            </svg>
          </div>
        )}

        {/* Play overlay on hover */}
        {isHovered && (
          <div className="absolute inset-0 bg-black/40 flex items-center justify-center">
            <svg className="w-7 h-7 text-white" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 14.5v-9l6 4.5-6 4.5z" />
            </svg>
          </div>
        )}
      </div>

      {/* Episode info */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="text-orange-400 text-[12px] font-bold">
            S{episode.season}E{episode.episode}
          </span>
        </div>
        {episode.title && (
          <p className="text-white text-[13px] truncate mt-0.5">{episode.title}</p>
        )}
        <div className="flex items-center gap-3 mt-1 text-[11px] text-gray-500">
          {episode.file_size != null && <span>{formatFileSize(episode.file_size)}</span>}
          {episode.duration != null && <span>{formatDuration(episode.duration)}</span>}
        </div>
      </div>

      {/* Play button */}
      <div className="shrink-0">
        <motion.button
          className="w-8 h-8 rounded-md bg-white/12 flex items-center justify-center
                     text-white hover:bg-white/20 transition-all duration-150"
          onClick={(e) => { e.stopPropagation(); onPlay(); }}
          whileTap={{ scale: 0.9 }}
        >
          <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
            <path d="M8 5v14l11-7z" />
          </svg>
        </motion.button>
      </div>
    </motion.div>
  );
}

/* ─── Main TVShowsView — matching macOS layout with inline detail ─── */

export default function TVShowsView() {
  const { tvShows } = useLibrary();
  const [selectedShow, setSelectedShow] = useState<TVShow | null>(null);
  const [selectedSeason, setSelectedSeason] = useState<number | null>(null);

  // Empty state
  if (tvShows.length === 0) {
    return (
      <motion.div
        className="flex flex-col items-center justify-center h-full text-cinema-text-dim"
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
      >
        <svg className="w-12 h-12 mb-4 opacity-20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
          <path d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
        </svg>
        <p className="text-lg font-medium mb-1">No TV Shows</p>
        <p className="text-sm">Scan a folder containing TV show files to get started</p>
      </motion.div>
    );
  }

  // Show detail view — inline, matching macOS showDetailView
  if (selectedShow) {
    const seasons = selectedShow.seasons || [];
    const episodes: TVEpisode[] = selectedSeason != null
      ? (seasons.find(s => s.season === selectedSeason)?.episodes || [])
      : seasons.flatMap(s => s.episodes);

    return (
      <div className="h-full flex flex-col">
        {/* Header — matching macOS show detail header */}
        <div className="px-6 py-4" style={{ backgroundColor: 'rgb(15, 15, 15)' }}>
          <div className="flex items-start gap-4">
            <motion.button
              onClick={() => { setSelectedShow(null); setSelectedSeason(null); }}
              className="mt-1 text-white hover:text-cinema-gold transition-colors"
              whileTap={{ scale: 0.9 }}
            >
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
              </svg>
            </motion.button>

            <div className="flex-1">
              <h2 className="text-[26px] font-bold text-white leading-tight">{selectedShow.name}</h2>
              <div className="flex items-center gap-3 mt-1 text-[13px] text-gray-400">
                <span>{selectedShow.episode_count || 0} episodes</span>
                {seasons.length > 0 && (
                  <span>{seasons.length} season{seasons.length === 1 ? '' : 's'}</span>
                )}
                {selectedShow.watched_count != null && selectedShow.watched_count > 0 && (
                  <span className="flex items-center gap-1 text-green-400">
                    <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
                    </svg>
                    {selectedShow.watched_count}/{selectedShow.episode_count || 0} watched
                  </span>
                )}
              </div>
              {selectedShow.description && (
                <p className="text-white/70 text-[13px] mt-2 line-clamp-2 leading-relaxed">{selectedShow.description}</p>
              )}
            </div>
          </div>
        </div>

        {/* Season pills — matching macOS horizontal scroll pills */}
        {seasons.length > 1 && (
          <div className="px-6 py-2.5 flex gap-2 overflow-x-auto hide-scrollbar" style={{ backgroundColor: 'rgb(20, 20, 20)' }}>
            <SeasonPill
              label="All"
              isSelected={selectedSeason == null}
              onClick={() => setSelectedSeason(null)}
            />
            {seasons.map(s => (
              <SeasonPill
                key={s.season}
                label={`Season ${s.season}`}
                isSelected={selectedSeason === s.season}
                onClick={() => setSelectedSeason(s.season)}
              />
            ))}
          </div>
        )}

        {/* Episodes list */}
        <div className="flex-1 overflow-y-auto px-6 py-3">
          <div className="space-y-0.5">
            {episodes.map((ep, i) => (
              <EpisodeRow
                key={ep.id}
                episode={ep}
                onPlay={() => {/* TODO: play episode */}}
                index={i}
              />
            ))}
          </div>
        </div>
      </div>
    );
  }

  // Grid view — matching macOS LazyVGrid with adaptive columns
  return (
    <div className="h-full overflow-y-auto">
      <div className="p-6">
        <div className="grid gap-6" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))' }}>
          {tvShows.map((show, i) => (
            <ShowCard
              key={show.id}
              show={show}
              index={i}
              onClick={() => {
                setSelectedShow(show);
                setSelectedSeason(null);
              }}
            />
          ))}
        </div>
      </div>
    </div>
  );
}
