import React, { useEffect, useState, useRef } from 'react';
import { motion, useInView } from 'framer-motion';
import { useAccounts } from '../hooks/useAccounts';
import { useServer } from '../hooks/useServer';
import { api } from '../api/client';
import * as localDb from '../db/local';
import type { LibraryStats } from '../api/types';

function AnimatedCounter({ value, suffix = '' }: { value: number | string; suffix?: string }) {
  const ref = useRef<HTMLSpanElement>(null);
  const isInView = useInView(ref, { once: true });
  const [display, setDisplay] = useState<string>(typeof value === 'string' ? '0' : '0');

  useEffect(() => {
    if (!isInView) return;

    if (typeof value === 'string') {
      setDisplay(value);
      return;
    }

    const target = value;
    if (target === 0) { setDisplay('0'); return; }

    const duration = 600;
    const startTime = Date.now();

    const animate = () => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(elapsed / duration, 1);
      // Ease out cubic
      const eased = 1 - Math.pow(1 - progress, 3);
      const current = Math.round(target * eased);
      setDisplay(String(current));
      if (progress < 1) requestAnimationFrame(animate);
    };

    requestAnimationFrame(animate);
  }, [value, isInView]);

  return (
    <motion.span
      ref={ref}
      className="tabular-nums"
      initial={{ opacity: 0, y: 8 }}
      animate={isInView ? { opacity: 1, y: 0 } : {}}
      transition={{ duration: 0.4, ease: 'easeOut' }}
    >
      {display}{suffix}
    </motion.span>
  );
}

function StatCard({ label, value, icon, delay = 0 }: { label: string; value: string | number; icon: React.ReactNode; delay?: number }) {
  return (
    <motion.div
      className="bg-cinema-surface rounded-xl p-4 border border-cinema-border
                 hover:border-cinema-border-hover hover:bg-cinema-surface/80
                 transition-all duration-250"
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay, duration: 0.35, ease: [0.4, 0, 0.2, 1] }}
      whileHover={{ scale: 1.02, y: -2 }}
    >
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-lg bg-cinema-gold/10 flex items-center justify-center text-cinema-gold">
          {icon}
        </div>
        <div>
          <div className="text-white text-xl font-bold">
            <AnimatedCounter value={value} />
          </div>
          <div className="text-cinema-text-dim text-xs">{label}</div>
        </div>
      </div>
    </motion.div>
  );
}

function formatWatchTime(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  if (hours > 0) return `${hours}h ${mins}m`;
  return `${mins}m`;
}

const GENRE_COLORS = [
  '#ef4444', '#f97316', '#eab308', '#22c55e', '#06b6d4',
  '#3b82f6', '#8b5cf6', '#ec4899', '#a855f7', '#14b8a6',
];

export default function ProfileView() {
  const { currentAccount } = useAccounts();
  const { isOnline } = useServer();
  const [stats, setStats] = useState<LibraryStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!currentAccount) return;
    const load = async () => {
      setLoading(true);
      try {
        if (isOnline) {
          setStats(await api.getStats(currentAccount.id));
        } else {
          setStats(await localDb.getStats(currentAccount.id));
        }
      } catch {
        setStats(null);
      }
      setLoading(false);
    };
    load();
  }, [currentAccount, isOnline]);

  if (!currentAccount) return null;

  // Donut chart calculations
  const qualityData = stats?.quality_distribution || [];
  const totalQuality = qualityData.reduce((a, q) => a + q.count, 0);
  const qualityColors: Record<string, string> = {
    '4K': '#8b5cf6', '2160p': '#8b5cf6',
    '1080p': '#3b82f6',
    '720p': '#22c55e',
    'SD': '#6b7280',
  };

  let cumulativePercent = 0;
  const donutSegments = qualityData.map((q) => {
    const percent = totalQuality > 0 ? q.count / totalQuality : 0;
    const startPercent = cumulativePercent;
    cumulativePercent += percent;
    return {
      ...q,
      color: qualityColors[q.quality] || '#6b7280',
      startPercent,
      percent,
    };
  });

  return (
    <div className="h-full overflow-y-auto p-6">
      {/* User header */}
      <motion.div
        className="flex items-center gap-4 mb-8"
        initial={{ opacity: 0, x: -20 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.4 }}
      >
        <motion.div
          className="w-16 h-16 rounded-2xl flex items-center justify-center text-2xl font-bold text-white"
          style={{
            backgroundColor: currentAccount.avatar_color,
            boxShadow: `0 4px 20px ${currentAccount.avatar_color}40`,
          }}
          whileHover={{ scale: 1.05 }}
        >
          {currentAccount.name.charAt(0).toUpperCase()}
        </motion.div>
        <div>
          <h2 className="text-white text-2xl font-bold">{currentAccount.name}</h2>
          <p className="text-cinema-text-secondary text-sm">Your viewing profile</p>
        </div>
      </motion.div>

      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-2 border-cinema-gold border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          {/* Stats cards */}
          <div className="grid grid-cols-4 gap-4 mb-8">
            <StatCard
              label="Movies Watched"
              value={stats?.movies_watched || 0}
              delay={0}
              icon={<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" /></svg>}
            />
            <StatCard
              label="Total Watch Time"
              value={formatWatchTime(stats?.total_watch_time || 0)}
              delay={0.05}
              icon={<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>}
            />
            <StatCard
              label="Avg Rating"
              value={stats?.avg_rating || '0.0'}
              delay={0.1}
              icon={<svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" /></svg>}
            />
            <StatCard
              label="Total in Library"
              value={stats?.movie_count || 0}
              delay={0.15}
              icon={<svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" /></svg>}
            />
          </div>

          <div className="grid grid-cols-2 gap-6">
            {/* Genre breakdown */}
            <motion.div
              className="bg-cinema-surface rounded-xl p-5 border border-cinema-border"
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2, duration: 0.35 }}
            >
              <h3 className="text-white text-sm font-semibold mb-4">Genre Breakdown</h3>
              {stats?.genre_breakdown && stats.genre_breakdown.length > 0 ? (
                <div className="space-y-3">
                  {stats.genre_breakdown.slice(0, 8).map((g, i) => {
                    const maxCount = Math.max(...stats.genre_breakdown.map((x) => x.count));
                    const barWidth = (g.count / maxCount) * 100;
                    const watchedWidth = (g.watched / maxCount) * 100;
                    return (
                      <div key={g.genre}>
                        <div className="flex justify-between text-xs mb-1">
                          <span className="text-cinema-text-secondary">{g.genre}</span>
                          <span className="text-cinema-text-dim tabular-nums">{g.watched}/{g.count}</span>
                        </div>
                        <div className="h-2 bg-cinema-bg rounded-full overflow-hidden relative">
                          <motion.div
                            className="absolute inset-y-0 left-0 rounded-full"
                            initial={{ width: 0 }}
                            animate={{ width: `${barWidth}%` }}
                            transition={{ delay: 0.3 + i * 0.05, duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
                            style={{ backgroundColor: GENRE_COLORS[i % GENRE_COLORS.length] + '30' }}
                          />
                          <motion.div
                            className="absolute inset-y-0 left-0 rounded-full"
                            initial={{ width: 0 }}
                            animate={{ width: `${watchedWidth}%` }}
                            transition={{ delay: 0.4 + i * 0.05, duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
                            style={{ backgroundColor: GENRE_COLORS[i % GENRE_COLORS.length] }}
                          />
                        </div>
                      </div>
                    );
                  })}
                </div>
              ) : (
                <p className="text-cinema-text-dim text-xs">No genre data yet</p>
              )}
            </motion.div>

            {/* Quality distribution (donut) */}
            <motion.div
              className="bg-cinema-surface rounded-xl p-5 border border-cinema-border"
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.25, duration: 0.35 }}
            >
              <h3 className="text-white text-sm font-semibold mb-4">Quality Distribution</h3>
              {donutSegments.length > 0 ? (
                <div className="flex items-center justify-center gap-6">
                  <div className="relative w-32 h-32">
                    <svg viewBox="0 0 42 42" className="donut-chart w-full h-full">
                      {donutSegments.map((seg, i) => {
                        const circumference = 2 * Math.PI * 15.91549;
                        const dashLength = seg.percent * circumference;
                        const dashOffset = -seg.startPercent * circumference;
                        return (
                          <motion.circle
                            key={i}
                            cx="21"
                            cy="21"
                            r="15.91549"
                            fill="transparent"
                            stroke={seg.color}
                            strokeWidth="4"
                            strokeLinecap="round"
                            initial={{ strokeDasharray: `0 ${circumference}` }}
                            animate={{ strokeDasharray: `${dashLength} ${circumference - dashLength}` }}
                            transition={{ delay: 0.4 + i * 0.1, duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
                            strokeDashoffset={dashOffset}
                          />
                        );
                      })}
                    </svg>
                    <div className="absolute inset-0 flex items-center justify-center">
                      <div className="text-center">
                        <div className="text-white text-lg font-bold">
                          <AnimatedCounter value={totalQuality} />
                        </div>
                        <div className="text-cinema-text-dim text-[10px]">Total</div>
                      </div>
                    </div>
                  </div>
                  <div className="space-y-2.5">
                    {donutSegments.map((seg, i) => (
                      <motion.div
                        key={i}
                        className="flex items-center gap-2"
                        initial={{ opacity: 0, x: 10 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: 0.5 + i * 0.05, duration: 0.2 }}
                      >
                        <div className="w-3 h-3 rounded-sm" style={{ backgroundColor: seg.color }} />
                        <span className="text-cinema-text-secondary text-xs">{seg.quality}</span>
                        <span className="text-white text-xs font-medium tabular-nums">{seg.count}</span>
                      </motion.div>
                    ))}
                  </div>
                </div>
              ) : (
                <p className="text-cinema-text-dim text-xs">No quality data yet</p>
              )}
            </motion.div>

            {/* Top Rated */}
            <motion.div
              className="bg-cinema-surface rounded-xl p-5 border border-cinema-border"
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3, duration: 0.35 }}
            >
              <h3 className="text-white text-sm font-semibold mb-4">Top Rated</h3>
              {stats?.top_rated && stats.top_rated.length > 0 ? (
                <div className="space-y-2">
                  {stats.top_rated.slice(0, 5).map((movie, i) => (
                    <motion.div
                      key={movie.id}
                      className="flex items-center gap-3 p-1.5 rounded-lg hover:bg-cinema-bg/40 transition-colors duration-150"
                      initial={{ opacity: 0, x: -8 }}
                      animate={{ opacity: 1, x: 0 }}
                      transition={{ delay: 0.35 + i * 0.04, duration: 0.2 }}
                    >
                      <span className="text-cinema-gold text-sm font-bold w-5 text-right tabular-nums">{i + 1}</span>
                      <div className="flex-1 min-w-0">
                        <p className="text-white text-sm truncate">{movie.title}</p>
                      </div>
                      <div className="flex items-center gap-1">
                        <svg className="w-3 h-3 text-cinema-gold" fill="currentColor" viewBox="0 0 20 20">
                          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                        </svg>
                        <span className="text-cinema-gold text-xs font-medium tabular-nums">{movie.user_rating.toFixed(1)}</span>
                      </div>
                    </motion.div>
                  ))}
                </div>
              ) : (
                <p className="text-cinema-text-dim text-xs">No ratings yet</p>
              )}
            </motion.div>

            {/* Recently Watched + Favorite Genres */}
            <div className="space-y-6">
              {/* Recently Watched */}
              <motion.div
                className="bg-cinema-surface rounded-xl p-5 border border-cinema-border"
                initial={{ opacity: 0, y: 15 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.35, duration: 0.35 }}
              >
                <h3 className="text-white text-sm font-semibold mb-4">Recently Watched</h3>
                {stats?.recently_watched && stats.recently_watched.length > 0 ? (
                  <div className="space-y-2">
                    {stats.recently_watched.slice(0, 4).map((wh, i) => (
                      <motion.div
                        key={wh.id}
                        className="flex items-center gap-3 p-1.5 rounded-lg hover:bg-cinema-bg/40 transition-colors duration-150"
                        initial={{ opacity: 0, x: -8 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: 0.4 + i * 0.04, duration: 0.2 }}
                      >
                        <div className="flex-1 min-w-0">
                          <p className="text-white text-sm truncate">{wh.movie?.title || 'Unknown'}</p>
                        </div>
                        <span className="text-cinema-text-dim text-xs shrink-0 tabular-nums">
                          {new Date(wh.last_watched).toLocaleDateString()}
                        </span>
                      </motion.div>
                    ))}
                  </div>
                ) : (
                  <p className="text-cinema-text-dim text-xs">Nothing watched yet</p>
                )}
              </motion.div>

              {/* Favorite Genres */}
              <motion.div
                className="bg-cinema-surface rounded-xl p-5 border border-cinema-border"
                initial={{ opacity: 0, y: 15 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.4, duration: 0.35 }}
              >
                <h3 className="text-white text-sm font-semibold mb-4">Favorite Genres</h3>
                {stats?.favorite_genres && stats.favorite_genres.length > 0 ? (
                  <div className="flex gap-2 flex-wrap">
                    {stats.favorite_genres.map((genre, i) => (
                      <motion.span
                        key={genre}
                        className="px-3 py-1.5 rounded-full text-xs font-medium text-white
                                   transition-all duration-200 hover:scale-105"
                        style={{
                          backgroundColor: GENRE_COLORS[i % GENRE_COLORS.length] + '25',
                          borderColor: GENRE_COLORS[i % GENRE_COLORS.length] + '60',
                          borderWidth: 1,
                        }}
                        initial={{ opacity: 0, scale: 0.8 }}
                        animate={{ opacity: 1, scale: 1 }}
                        transition={{ delay: 0.45 + i * 0.04, duration: 0.25 }}
                      >
                        {genre}
                      </motion.span>
                    ))}
                  </div>
                ) : (
                  <p className="text-cinema-text-dim text-xs">Favorite some movies to see genre preferences</p>
                )}
              </motion.div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
