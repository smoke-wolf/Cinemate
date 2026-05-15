import React from 'react';
import { motion } from 'framer-motion';
import { useLibrary } from '../hooks/useLibrary';
import type { MainTab, SortOption, QualityFilter } from '../api/types';

const NAV_ITEMS: { tab: MainTab; label: string; icon: React.ReactNode }[] = [
  {
    tab: 'browse',
    label: 'Browse',
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zm10 0a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zm10 0a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
      </svg>
    ),
  },
  {
    tab: 'tvshows',
    label: 'TV Shows',
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
      </svg>
    ),
  },
  {
    tab: 'music',
    label: 'Music',
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
      </svg>
    ),
  },
  {
    tab: 'favorites',
    label: 'Favorites',
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
      </svg>
    ),
  },
  {
    tab: 'recent',
    label: 'Recently Played',
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
  },
  {
    tab: 'profile',
    label: 'Profile',
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
      </svg>
    ),
  },
  {
    tab: 'admin',
    label: 'LAN Admin',
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01" />
      </svg>
    ),
  },
];

const SORT_OPTIONS: { value: SortOption; label: string }[] = [
  { value: 'title', label: 'Title' },
  { value: 'year', label: 'Year' },
  { value: 'date_added', label: 'Date Added' },
  { value: 'last_played', label: 'Last Played' },
  { value: 'file_size', label: 'File Size' },
];

const QUALITY_OPTIONS: { value: QualityFilter; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: '4k', label: '4K' },
  { value: '1080p', label: '1080p' },
  { value: '720p', label: '720p' },
];

export default function Sidebar() {
  const {
    activeTab, setActiveTab,
    sortBy, setSortBy,
    qualityFilter, setQualityFilter,
    movies, tvShows, watchHistory,
    scanFolder,
    musicTrackCount,
  } = useLibrary();

  const totalWatchTime = watchHistory.reduce((acc, wh) => {
    const dur = wh.movie?.duration || 0;
    return acc + dur * wh.progress;
  }, 0);

  const formatTime = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    if (hours > 0) return `${hours}h ${mins}m`;
    return `${mins}m`;
  };

  return (
    <div className="w-[200px] h-full bg-cinema-sidebar border-r border-cinema-border flex flex-col pt-10">
      {/* Logo */}
      <div className="px-5 mb-8">
        <h1 className="text-logo-gradient text-xl font-extrabold tracking-wider">CINEMATE</h1>
        <div className="mt-1.5 h-px bg-gradient-to-r from-cinema-gold/30 via-cinema-gold/10 to-transparent" />
      </div>

      {/* Nav tabs */}
      <nav className="flex-1 px-2 space-y-0.5">
        {NAV_ITEMS.map((item) => (
          <motion.button
            key={item.tab}
            onClick={() => setActiveTab(item.tab)}
            className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium
                        transition-all duration-200 relative group
                        ${activeTab === item.tab
                          ? 'text-cinema-gold bg-cinema-gold/10'
                          : 'text-cinema-text-secondary hover:text-white hover:bg-white/[0.04]'
                        }`}
            whileTap={{ scale: 0.98 }}
          >
            {activeTab === item.tab && (
              <motion.div
                layoutId="sidebar-active"
                className="absolute left-0 top-1/2 -translate-y-1/2 w-[3px] h-5 bg-cinema-gold rounded-r-full"
                transition={{ type: 'spring', stiffness: 350, damping: 30 }}
                style={{ boxShadow: '2px 0 8px rgba(212, 160, 23, 0.3)' }}
              />
            )}
            <span className={`transition-colors duration-200 ${activeTab === item.tab ? 'text-cinema-gold' : 'text-cinema-text-dim group-hover:text-cinema-text-secondary'}`}>
              {item.icon}
            </span>
            {item.label}
          </motion.button>
        ))}
      </nav>

      {/* Library stats */}
      <div className="px-4 py-3 border-t border-cinema-border">
        <div className="text-cinema-text-dim text-[10px] uppercase tracking-wider mb-2.5 font-semibold">Library</div>
        <div className="space-y-1.5 text-xs">
          <div className="flex justify-between text-cinema-text-secondary">
            <span>Movies</span>
            <span className="text-white font-medium tabular-nums">{movies.length}</span>
          </div>
          <div className="flex justify-between text-cinema-text-secondary">
            <span>Shows</span>
            <span className="text-white font-medium tabular-nums">{tvShows.length}</span>
          </div>
          <div className="flex justify-between text-cinema-text-secondary">
            <span>Tracks</span>
            <span className="text-white font-medium tabular-nums">{musicTrackCount}</span>
          </div>
          <div className="flex justify-between text-cinema-text-secondary">
            <span>Watch Time</span>
            <span className="text-white font-medium tabular-nums">{formatTime(totalWatchTime)}</span>
          </div>
        </div>
      </div>

      {/* Scan folder button */}
      <div className="px-4 py-3 border-t border-cinema-border">
        <motion.button
          onClick={scanFolder}
          className="w-full py-2 px-3 bg-cinema-surface hover:bg-cinema-card rounded-lg text-cinema-text-secondary
                     hover:text-white text-xs font-medium transition-all duration-200 flex items-center gap-2 justify-center
                     border border-transparent hover:border-cinema-border"
          whileHover={{ scale: 1.01 }}
          whileTap={{ scale: 0.98 }}
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
          </svg>
          Scan Folder
        </motion.button>
      </div>

      {/* Sort dropdown */}
      <div className="px-4 py-3 border-t border-cinema-border">
        <label className="block text-cinema-text-dim text-[10px] uppercase tracking-wider mb-1.5 font-semibold">Sort By</label>
        <select
          value={sortBy}
          onChange={(e) => setSortBy(e.target.value as SortOption)}
          className="w-full bg-cinema-surface border border-cinema-border rounded-lg px-2.5 py-1.5 text-xs text-white
                     focus:outline-none focus:border-cinema-gold/50 focus:ring-1 focus:ring-cinema-gold/20 cursor-pointer
                     transition-all duration-200 appearance-none
                     hover:border-cinema-border-hover"
          style={{
            backgroundImage: `url("data:image/svg+xml,%3Csvg width='10' height='6' viewBox='0 0 10 6' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M1 1L5 5L9 1' stroke='%236b7280' stroke-width='1.5' stroke-linecap='round'/%3E%3C/svg%3E")`,
            backgroundRepeat: 'no-repeat',
            backgroundPosition: 'right 8px center',
            paddingRight: '28px',
          }}
        >
          {SORT_OPTIONS.map((opt) => (
            <option key={opt.value} value={opt.value}>{opt.label}</option>
          ))}
        </select>
      </div>

      {/* Quality filter */}
      <div className="px-4 py-3 border-t border-cinema-border">
        <label className="block text-cinema-text-dim text-[10px] uppercase tracking-wider mb-1.5 font-semibold">Quality</label>
        <div className="flex flex-wrap gap-1">
          {QUALITY_OPTIONS.map((opt) => (
            <motion.button
              key={opt.value}
              onClick={() => setQualityFilter(opt.value)}
              className={`px-2.5 py-1 rounded-md text-[10px] font-semibold transition-all duration-200
                          ${qualityFilter === opt.value
                            ? 'bg-cinema-gold text-black shadow-sm shadow-cinema-gold/20'
                            : 'bg-cinema-surface text-cinema-text-dim hover:text-white hover:bg-cinema-card'
                          }`}
              whileTap={{ scale: 0.95 }}
            >
              {opt.label}
            </motion.button>
          ))}
        </div>
      </div>
    </div>
  );
}
