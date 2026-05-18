import React from 'react';
import { motion } from 'framer-motion';
import { useLibrary } from '../hooks/useLibrary';
import type { MainTab, SortOption, QualityFilter } from '../api/types';

/* ─── Section configuration matching macOS SidebarView.swift ─── */

interface NavItem {
  tab: MainTab;
  label: string;
  icon: string; // SVG path data
  viewBox?: string;
  filled?: boolean;
}

const MAIN_NAV: NavItem[] = [
  {
    tab: 'browse',
    label: 'Browse',
    icon: 'M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zm10 0a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zm10 0a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z',
  },
  {
    tab: 'tvshows',
    label: 'TV Shows',
    icon: 'M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z',
  },
  {
    tab: 'favorites',
    label: 'Favorites',
    icon: 'M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z',
    filled: true,
  },
  {
    tab: 'recent',
    label: 'Recent',
    icon: 'M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z',
  },
  {
    tab: 'downloads',
    label: 'Downloads',
    icon: 'M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4',
  },
];

const MEDIA_NAV: NavItem[] = [
  {
    tab: 'music',
    label: 'Music',
    icon: 'M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3',
  },
  {
    tab: 'books',
    label: 'Books',
    icon: 'M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253',
  },
];

const ADMIN_NAV: NavItem[] = [
  {
    tab: 'devices',
    label: 'Devices',
    icon: 'M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z',
  },
  {
    tab: 'profile',
    label: 'Profile',
    icon: 'M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z',
  },
  {
    tab: 'settings',
    label: 'Settings',
    icon: 'M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z M15 12a3 3 0 11-6 0 3 3 0 016 0z',
  },
  {
    tab: 'wan',
    label: 'WAN Settings',
    icon: 'M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
  },
  {
    tab: 'admin',
    label: 'LAN Admin',
    icon: 'M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01',
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

function SectionHeader({ label }: { label: string }) {
  return (
    <div className="px-5 pt-5 pb-1.5">
      <span className="text-cinema-text-dim text-[10px] uppercase tracking-[0.08em] font-semibold">
        {label}
      </span>
    </div>
  );
}

function NavButton({
  item,
  isActive,
  onClick,
  badge,
}: {
  item: NavItem;
  isActive: boolean;
  onClick: () => void;
  badge?: number;
}) {
  return (
    <motion.button
      onClick={onClick}
      className={`w-full flex items-center gap-2.5 px-3 py-[7px] rounded-md text-[13px] font-medium
                  transition-all duration-200 relative group
                  ${isActive
                    ? 'text-white bg-white/10'
                    : 'text-gray-400 hover:text-white hover:bg-white/[0.04]'
                  }`}
      whileTap={{ scale: 0.98 }}
    >
      {/* Active indicator bar */}
      {isActive && (
        <motion.div
          layoutId="sidebar-active"
          className="absolute left-0 top-1/2 -translate-y-1/2 w-[3px] h-5 rounded-r-full"
          transition={{ type: 'spring', stiffness: 350, damping: 30 }}
          style={{
            background: 'linear-gradient(180deg, #ecbf3b, #d4a017)',
            boxShadow: '2px 0 10px rgba(212, 160, 23, 0.4)',
          }}
        />
      )}

      {/* Icon */}
      <svg
        className={`w-[18px] h-[18px] flex-shrink-0 transition-colors duration-200
                    ${isActive ? 'text-cinema-gold' : 'text-cinema-text-dim group-hover:text-cinema-text-secondary'}`}
        fill={item.filled && isActive ? 'currentColor' : 'none'}
        viewBox="0 0 24 24"
        stroke="currentColor"
        strokeWidth={1.5}
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d={item.icon} />
      </svg>

      {/* Label */}
      <span className={isActive ? 'text-white' : ''}>{item.label}</span>

      {/* Badge */}
      {badge != null && badge > 0 && (
        <span className="ml-auto px-1.5 py-0.5 min-w-[20px] text-center bg-cinema-blue rounded-full text-[10px] font-bold text-white">
          {badge}
        </span>
      )}
    </motion.button>
  );
}

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
    <div className="w-[200px] h-full flex flex-col pt-5" style={{ backgroundColor: 'rgb(15, 15, 15)' }}>
      {/* Logo — matching macOS red/orange gradient */}
      <div className="px-5 mb-6">
        <h1 className="text-logo-gradient text-2xl font-black tracking-wider">CINEMATE</h1>
      </div>

      {/* Main navigation */}
      <nav className="flex-1 overflow-y-auto overflow-x-hidden px-2 space-y-0.5">
        {MAIN_NAV.map((item) => (
          <NavButton
            key={item.tab}
            item={item}
            isActive={activeTab === item.tab}
            onClick={() => setActiveTab(item.tab)}
          />
        ))}

        {/* Divider */}
        <div className="py-3 px-3">
          <div className="h-px bg-gray-700/30" />
        </div>

        {/* Media section */}
        <SectionHeader label="Media" />
        {MEDIA_NAV.map((item) => (
          <NavButton
            key={item.tab}
            item={item}
            isActive={activeTab === item.tab}
            onClick={() => setActiveTab(item.tab)}
          />
        ))}

        {/* Divider */}
        <div className="py-3 px-3">
          <div className="h-px bg-gray-700/30" />
        </div>

        {/* Admin section */}
        <SectionHeader label="Admin" />
        {ADMIN_NAV.map((item) => (
          <NavButton
            key={item.tab}
            item={item}
            isActive={activeTab === item.tab}
            onClick={() => setActiveTab(item.tab)}
          />
        ))}
      </nav>

      {/* Library stats — matching macOS sidebar bottom */}
      <div className="px-5 py-3">
        <div className="text-cinema-text-dim text-[11px] uppercase tracking-wider mb-2 font-semibold">Library</div>
        <div className="space-y-1 text-[12px]">
          <div className="flex items-center gap-1.5 text-gray-400">
            <svg className="w-[11px] h-[11px] opacity-60" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
            </svg>
            <span>{movies.length} movies</span>
          </div>
          {tvShows.length > 0 && (
            <div className="flex items-center gap-1.5 text-gray-400">
              <svg className="w-[11px] h-[11px] opacity-60" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              <span>{tvShows.length} shows</span>
            </div>
          )}
          {musicTrackCount > 0 && (
            <div className="flex items-center gap-1.5 text-gray-400">
              <svg className="w-[11px] h-[11px] opacity-60" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z" />
              </svg>
              <span>{musicTrackCount} tracks</span>
            </div>
          )}
          {totalWatchTime > 0 && (
            <div className="flex items-center gap-1.5 text-gray-400">
              <svg className="w-[11px] h-[11px] opacity-60" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 2C6.477 2 2 6.477 2 12s4.477 10 10 10 10-4.477 10-10S17.523 2 12 2zm0 18a8 8 0 110-16 8 8 0 010 16zm1-13h-2v6l5.25 3.15.75-1.23-4-2.42V7z" />
              </svg>
              <span>{formatTime(totalWatchTime)} watched</span>
            </div>
          )}
        </div>
      </div>

      {/* Divider */}
      <div className="px-4">
        <div className="h-px bg-gray-700/20" />
      </div>

      {/* Scan + Sort row — matching macOS bottom controls */}
      <div className="px-3 py-2.5 flex items-center gap-0">
        <motion.button
          onClick={scanFolder}
          className="flex items-center gap-1.5 px-2.5 py-1.5 bg-white/[0.06] hover:bg-white/[0.1] rounded-md
                     text-white/60 hover:text-white text-[11px] font-medium transition-all duration-200"
          whileTap={{ scale: 0.95 }}
        >
          <svg className="w-[11px] h-[11px]" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
          </svg>
          Scan
        </motion.button>

        <div className="flex-1" />

        <div className="relative">
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value as SortOption)}
            className="appearance-none bg-white/[0.06] hover:bg-white/[0.1] rounded-md px-2 py-1.5 pr-5
                       text-white/60 hover:text-white text-[11px] font-medium cursor-pointer
                       border-none outline-none transition-all duration-200"
          >
            {SORT_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value} className="bg-cinema-card text-white">{opt.label}</option>
            ))}
          </select>
          <svg className="absolute right-1.5 top-1/2 -translate-y-1/2 w-[9px] h-[9px] text-white/40 pointer-events-none" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
            <path d="M19 9l-7 7-7-7" />
          </svg>
        </div>
      </div>

      {/* Quality filter chips — 2x2 grid matching macOS */}
      <div className="px-3 pb-4 pt-1.5">
        <div className="grid grid-cols-2 gap-1.5">
          {QUALITY_OPTIONS.map((opt) => {
            const isActive = qualityFilter === opt.value;
            return (
              <motion.button
                key={opt.value}
                onClick={() => setQualityFilter(opt.value)}
                className={`py-[5px] rounded-md text-[11px] font-medium transition-all duration-200 text-center
                            ${isActive
                              ? 'bg-cinema-gold text-black font-semibold'
                              : 'bg-white/[0.06] text-white/60 hover:text-white hover:bg-white/[0.1]'
                            }`}
                whileTap={{ scale: 0.95 }}
                style={isActive ? { boxShadow: '0 2px 8px rgba(212, 160, 23, 0.25)' } : {}}
              >
                {opt.label}
              </motion.button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
