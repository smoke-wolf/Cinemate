import React, { useState, useEffect, useCallback, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import type { MusicTrack, MusicAlbum, MusicArtist, MusicGenre, Playlist } from '../api/types';
import { api } from '../api/client';
import { useAccounts } from '../hooks/useAccounts';
import AlbumDetailView from './AlbumDetailView';
import ArtistDetailView from './ArtistDetailView';

type MusicSubTab = 'browse' | 'tracks' | 'artists' | 'albums' | 'playlists';
type TrackSortKey = 'title' | 'artist' | 'album' | 'duration';

interface MusicViewProps {
  onPlayTrack: (track: MusicTrack, queue: MusicTrack[]) => void;
}

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function formatTotalDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h > 0) return `${h} hr ${m} min`;
  return `${m} min`;
}

const SUB_TABS: { key: MusicSubTab; label: string }[] = [
  { key: 'browse', label: 'Browse' },
  { key: 'tracks', label: 'Tracks' },
  { key: 'artists', label: 'Artists' },
  { key: 'albums', label: 'Albums' },
  { key: 'playlists', label: 'Playlists' },
];

export default function MusicView({ onPlayTrack }: MusicViewProps) {
  const { currentAccount } = useAccounts();

  // Sub-tab state
  const [subTab, setSubTab] = useState<MusicSubTab>('browse');

  // Detail views
  const [detailAlbumId, setDetailAlbumId] = useState<number | null>(null);
  const [detailArtistName, setDetailArtistName] = useState<string | null>(null);

  // Search
  const [search, setSearch] = useState('');
  const searchDebounce = useRef<ReturnType<typeof setTimeout>>();

  // Data
  const [tracks, setTracks] = useState<MusicTrack[]>([]);
  const [tracksTotal, setTracksTotal] = useState(0);
  const [artists, setArtists] = useState<MusicArtist[]>([]);
  const [albums, setAlbums] = useState<MusicAlbum[]>([]);
  const [genres, setGenres] = useState<MusicGenre[]>([]);
  const [recentlyPlayed, setRecentlyPlayed] = useState<MusicTrack[]>([]);
  const [favorites, setFavorites] = useState<MusicTrack[]>([]);
  const [playlists, setPlaylists] = useState<Playlist[]>([]);
  const [loading, setLoading] = useState(true);

  // Tracks sort state
  const [trackSort, setTrackSort] = useState<TrackSortKey>('title');
  const [trackSortOrder, setTrackSortOrder] = useState<'asc' | 'desc'>('asc');

  // Playlist creation
  const [showNewPlaylist, setShowNewPlaylist] = useState(false);
  const [newPlaylistName, setNewPlaylistName] = useState('');

  // Load data
  const loadBrowseData = useCallback(async () => {
    try {
      const [genreData, recentData, favData] = await Promise.all([
        api.getMusicGenres(),
        currentAccount ? api.getRecentlyPlayedMusic(currentAccount.id) : Promise.resolve([]),
        currentAccount ? api.getMusicFavorites(currentAccount.id) : Promise.resolve([]),
      ]);
      setGenres(genreData.genres);
      setRecentlyPlayed(recentData);
      setFavorites(favData);
    } catch {}
  }, [currentAccount]);

  const loadTracks = useCallback(async (searchTerm?: string) => {
    try {
      const data = await api.getMusicTracks({
        search: searchTerm || undefined,
        sort: trackSort,
        order: trackSortOrder,
        limit: 200,
      });
      setTracks(data.items);
      setTracksTotal(data.total);
    } catch {}
  }, [trackSort, trackSortOrder]);

  const loadArtists = useCallback(async (searchTerm?: string) => {
    try {
      const data = await api.getMusicArtists({ search: searchTerm || undefined, limit: 200 });
      setArtists(data.items);
    } catch {}
  }, []);

  const loadAlbums = useCallback(async (searchTerm?: string) => {
    try {
      const data = await api.getMusicAlbums({ search: searchTerm || undefined });
      setAlbums(data.items);
    } catch {}
  }, []);

  const loadPlaylists = useCallback(async () => {
    if (!currentAccount) return;
    try {
      setPlaylists(await api.getPlaylists(currentAccount.id));
    } catch {}
  }, [currentAccount]);

  // Initial load
  useEffect(() => {
    setLoading(true);
    Promise.all([
      loadBrowseData(),
      loadTracks(),
      loadArtists(),
      loadAlbums(),
      loadPlaylists(),
    ]).finally(() => setLoading(false));
  }, []);

  // Reload on tab change
  useEffect(() => {
    if (subTab === 'tracks') loadTracks(search);
    if (subTab === 'artists') loadArtists(search);
    if (subTab === 'albums') loadAlbums(search);
    if (subTab === 'playlists') loadPlaylists();
    if (subTab === 'browse') loadBrowseData();
  }, [subTab]);

  // Re-sort tracks
  useEffect(() => {
    if (subTab === 'tracks') loadTracks(search);
  }, [trackSort, trackSortOrder]);

  // Debounced search
  const handleSearch = (value: string) => {
    setSearch(value);
    if (searchDebounce.current) clearTimeout(searchDebounce.current);
    searchDebounce.current = setTimeout(() => {
      if (subTab === 'tracks') loadTracks(value);
      else if (subTab === 'artists') loadArtists(value);
      else if (subTab === 'albums') loadAlbums(value);
    }, 300);
  };

  const handleTrackSortClick = (key: TrackSortKey) => {
    if (trackSort === key) {
      setTrackSortOrder((o) => (o === 'asc' ? 'desc' : 'asc'));
    } else {
      setTrackSort(key);
      setTrackSortOrder('asc');
    }
  };

  const handleCreatePlaylist = async () => {
    if (!currentAccount || !newPlaylistName.trim()) return;
    try {
      await api.createPlaylist(currentAccount.id, { name: newPlaylistName.trim() });
      setNewPlaylistName('');
      setShowNewPlaylist(false);
      loadPlaylists();
    } catch {}
  };

  const handleDeletePlaylist = async (pid: number) => {
    if (!currentAccount) return;
    try {
      await api.deletePlaylist(currentAccount.id, pid);
      loadPlaylists();
    } catch {}
  };

  // If showing album or artist detail, render that instead
  if (detailAlbumId !== null) {
    return (
      <AlbumDetailView
        albumId={detailAlbumId}
        onBack={() => setDetailAlbumId(null)}
        onPlayTrack={onPlayTrack}
        onArtistClick={(name) => { setDetailAlbumId(null); setDetailArtistName(name); }}
      />
    );
  }

  if (detailArtistName !== null) {
    return (
      <ArtistDetailView
        artistName={detailArtistName}
        onBack={() => setDetailArtistName(null)}
        onAlbumClick={(id) => { setDetailArtistName(null); setDetailAlbumId(id); }}
        onPlayTrack={onPlayTrack}
      />
    );
  }

  const SortIcon = ({ active, asc }: { active: boolean; asc: boolean }) => (
    <svg className={`w-3 h-3 inline ml-1 transition-colors duration-150 ${active ? 'text-cinema-gold' : 'text-cinema-text-dim'}`}
         fill="none" viewBox="0 0 24 24" stroke="currentColor">
      {active && !asc ? (
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
      ) : (
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 15l7-7 7 7" />
      )}
    </svg>
  );

  return (
    <div className="h-full overflow-y-auto">
      {/* Header area */}
      <div className="sticky top-0 z-20 bg-cinema-bg/95 backdrop-blur-lg border-b border-cinema-border">
        <div className="px-6 pt-6 pb-0">
          <motion.h2
            className="text-white text-xl font-semibold mb-4"
            initial={{ opacity: 0, x: -10 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.3 }}
          >
            Music
          </motion.h2>

          {/* Sub-tabs + search */}
          <div className="flex items-center justify-between gap-4">
            <div className="flex items-center gap-1">
              {SUB_TABS.map((tab) => (
                <button
                  key={tab.key}
                  onClick={() => setSubTab(tab.key)}
                  className={`relative px-3.5 py-2 text-sm font-medium rounded-lg transition-all duration-200
                             ${subTab === tab.key
                               ? 'text-cinema-gold'
                               : 'text-cinema-text-secondary hover:text-white hover:bg-white/[0.04]'
                             }`}
                >
                  {tab.label}
                  {subTab === tab.key && (
                    <motion.div
                      layoutId="music-subtab"
                      className="absolute bottom-0 left-3 right-3 h-0.5 bg-cinema-gold rounded-full"
                      transition={{ type: 'spring', stiffness: 350, damping: 30 }}
                    />
                  )}
                </button>
              ))}
            </div>

            {/* Search */}
            {subTab !== 'browse' && subTab !== 'playlists' && (
              <div className="relative">
                <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-cinema-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                <input
                  type="text"
                  placeholder="Search..."
                  value={search}
                  onChange={(e) => handleSearch(e.target.value)}
                  className="bg-cinema-surface border border-cinema-border rounded-lg pl-9 pr-3 py-1.5
                             text-sm text-white placeholder:text-cinema-text-dim
                             focus:outline-none focus:border-cinema-gold/50 focus:ring-1 focus:ring-cinema-gold/20
                             w-56 transition-all duration-200"
                />
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="p-6 pb-32">
        {loading ? (
          <div className="flex items-center justify-center py-20">
            <div className="w-8 h-8 border-2 border-cinema-gold/30 border-t-cinema-gold rounded-full animate-spin" />
          </div>
        ) : (
          <>
            {/* Browse tab */}
            {subTab === 'browse' && (
              <div>
                {/* Recently played row */}
                {recentlyPlayed.length > 0 && (
                  <div className="mb-8">
                    <h3 className="text-white text-lg font-semibold mb-3">Recently Played</h3>
                    <div className="flex gap-4 overflow-x-auto hide-scrollbar pb-2">
                      {recentlyPlayed.slice(0, 20).map((track, i) => (
                        <TrackCard
                          key={`recent-${track.id}-${i}`}
                          track={track}
                          onPlay={() => onPlayTrack(track, recentlyPlayed)}
                          onAlbumClick={setDetailAlbumId}
                        />
                      ))}
                    </div>
                  </div>
                )}

                {/* Favorites row */}
                {favorites.length > 0 && (
                  <div className="mb-8">
                    <h3 className="text-white text-lg font-semibold mb-3">Favorites</h3>
                    <div className="flex gap-4 overflow-x-auto hide-scrollbar pb-2">
                      {favorites.slice(0, 20).map((track, i) => (
                        <TrackCard
                          key={`fav-${track.id}-${i}`}
                          track={track}
                          onPlay={() => onPlayTrack(track, favorites)}
                          onAlbumClick={setDetailAlbumId}
                        />
                      ))}
                    </div>
                  </div>
                )}

                {/* Genre sections */}
                {genres.length > 0 && (
                  <div>
                    <h3 className="text-white text-lg font-semibold mb-4">Genres</h3>
                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3">
                      {genres.map((g, i) => (
                        <motion.button
                          key={g.genre}
                          onClick={() => { setSubTab('tracks'); handleSearch(g.genre); setSearch(g.genre); }}
                          className="relative overflow-hidden rounded-xl p-4 text-left
                                     bg-cinema-surface hover:bg-cinema-card transition-all duration-200
                                     ring-1 ring-white/[0.04] hover:ring-white/[0.08] group"
                          initial={{ opacity: 0, y: 10 }}
                          animate={{ opacity: 1, y: 0 }}
                          transition={{ delay: i * 0.03, duration: 0.25 }}
                          whileHover={{ scale: 1.02 }}
                        >
                          <div
                            className="absolute inset-0 opacity-10"
                            style={{
                              background: `linear-gradient(135deg, hsl(${(g.genre.charCodeAt(0) * 17) % 360}, 50%, 30%), transparent)`,
                            }}
                          />
                          <p className="text-white text-sm font-medium relative group-hover:text-cinema-gold transition-colors duration-200">
                            {g.genre}
                          </p>
                          <p className="text-cinema-text-dim text-xs relative mt-0.5">{g.count} tracks</p>
                        </motion.button>
                      ))}
                    </div>
                  </div>
                )}

                {recentlyPlayed.length === 0 && favorites.length === 0 && genres.length === 0 && (
                  <EmptyState message="No music in your library yet." />
                )}
              </div>
            )}

            {/* Tracks tab */}
            {subTab === 'tracks' && (
              <div>
                <div className="text-cinema-text-dim text-xs mb-3">{tracksTotal} tracks</div>
                {/* Table header */}
                <div className="flex items-center gap-4 px-4 py-2 border-b border-cinema-border mb-1
                                text-cinema-text-dim text-xs uppercase tracking-wider font-semibold select-none">
                  <span className="w-8 text-right">#</span>
                  <button className="flex-[2] text-left flex items-center cursor-pointer hover:text-white transition-colors"
                          onClick={() => handleTrackSortClick('title')}>
                    Title <SortIcon active={trackSort === 'title'} asc={trackSortOrder === 'asc'} />
                  </button>
                  <button className="flex-1 text-left flex items-center cursor-pointer hover:text-white transition-colors"
                          onClick={() => handleTrackSortClick('artist')}>
                    Artist <SortIcon active={trackSort === 'artist'} asc={trackSortOrder === 'asc'} />
                  </button>
                  <button className="flex-1 text-left flex items-center cursor-pointer hover:text-white transition-colors"
                          onClick={() => handleTrackSortClick('album')}>
                    Album <SortIcon active={trackSort === 'album'} asc={trackSortOrder === 'asc'} />
                  </button>
                  <button className="w-20 text-right flex items-center justify-end cursor-pointer hover:text-white transition-colors"
                          onClick={() => handleTrackSortClick('duration')}>
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <SortIcon active={trackSort === 'duration'} asc={trackSortOrder === 'asc'} />
                  </button>
                </div>

                {tracks.map((track, i) => (
                  <motion.div
                    key={track.id}
                    className="flex items-center gap-4 px-4 py-2 rounded-lg group cursor-pointer
                               hover:bg-white/[0.04] transition-all duration-150"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: Math.min(i * 0.01, 0.5), duration: 0.15 }}
                    onClick={() => onPlayTrack(track, tracks)}
                  >
                    <span className="w-8 text-right text-cinema-text-dim text-sm tabular-nums font-mono
                                    group-hover:hidden">{i + 1}</span>
                    <span className="w-8 text-right hidden group-hover:block">
                      <svg className="w-4 h-4 text-cinema-gold ml-auto" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M8 5v14l11-7z" />
                      </svg>
                    </span>
                    <div className="flex-[2] min-w-0">
                      <p className="text-white text-sm truncate group-hover:text-cinema-gold transition-colors duration-150">
                        {track.title}
                      </p>
                    </div>
                    <button
                      className="flex-1 min-w-0 text-left"
                      onClick={(e) => { e.stopPropagation(); setDetailArtistName(track.artist); }}
                    >
                      <p className="text-cinema-text-secondary text-sm truncate hover:text-cinema-gold
                                    transition-colors duration-150">{track.artist}</p>
                    </button>
                    <button
                      className="flex-1 min-w-0 text-left"
                      onClick={(e) => { e.stopPropagation(); if (track.album_id) setDetailAlbumId(track.album_id); }}
                    >
                      <p className="text-cinema-text-secondary text-sm truncate hover:text-cinema-gold
                                    transition-colors duration-150">{track.album}</p>
                    </button>
                    <span className="w-20 text-right text-cinema-text-dim text-sm tabular-nums">
                      {formatDuration(track.duration)}
                    </span>
                  </motion.div>
                ))}

                {tracks.length === 0 && <EmptyState message="No tracks found." />}
              </div>
            )}

            {/* Artists tab */}
            {subTab === 'artists' && (
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-5">
                {artists.map((artist, i) => {
                  const hue = artist.artist.split('').reduce((a, c) => a + c.charCodeAt(0), 0) % 360;
                  return (
                    <motion.div
                      key={artist.artist}
                      className="group cursor-pointer text-center"
                      initial={{ opacity: 0, y: 15 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: Math.min(i * 0.03, 0.5), duration: 0.3 }}
                      whileHover={{ scale: 1.03, y: -4 }}
                      onClick={() => setDetailArtistName(artist.artist)}
                    >
                      <div
                        className="w-full aspect-square rounded-full mx-auto overflow-hidden
                                   ring-2 ring-white/[0.06] group-hover:ring-cinema-gold/30
                                   transition-all duration-300 shadow-lg shadow-black/30
                                   flex items-center justify-center"
                        style={{ background: `linear-gradient(135deg, hsl(${hue}, 40%, 18%), hsl(${(hue + 60) % 360}, 50%, 28%))` }}
                      >
                        <svg className="w-12 h-12 text-white/15" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                        </svg>
                      </div>
                      <h3 className="text-white text-sm font-medium truncate mt-3 group-hover:text-cinema-gold
                                     transition-colors duration-200">{artist.artist}</h3>
                      <p className="text-cinema-text-dim text-xs mt-0.5">
                        {artist.album_count} album{artist.album_count !== 1 ? 's' : ''}
                      </p>
                    </motion.div>
                  );
                })}
                {artists.length === 0 && (
                  <div className="col-span-full">
                    <EmptyState message="No artists found." />
                  </div>
                )}
              </div>
            )}

            {/* Albums tab */}
            {subTab === 'albums' && (
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-5">
                {albums.map((album, i) => (
                  <motion.div
                    key={album.id}
                    className="group cursor-pointer"
                    initial={{ opacity: 0, y: 15 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: Math.min(i * 0.03, 0.5), duration: 0.3 }}
                    whileHover={{ scale: 1.03, y: -4 }}
                    onClick={() => setDetailAlbumId(album.id)}
                  >
                    <div className="relative aspect-square rounded-xl overflow-hidden bg-cinema-surface
                                    ring-1 ring-white/[0.04] group-hover:ring-white/[0.08]
                                    group-hover:shadow-xl group-hover:shadow-black/40
                                    transition-all duration-300 mb-2">
                      <img
                        src={api.getMusicArtUrl(album.id)}
                        alt={album.name}
                        className="w-full h-full object-cover"
                        onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                      />
                      <div className="absolute inset-0 flex items-center justify-center -z-10">
                        <svg className="w-12 h-12 text-cinema-text-dim/20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9 19V6l12-3v13" />
                        </svg>
                      </div>
                      <div className="absolute inset-0 bg-gradient-to-t from-black/50 to-transparent
                                      opacity-0 group-hover:opacity-100 transition-opacity duration-250" />
                      <div className="absolute inset-0 flex items-center justify-center">
                        <motion.div
                          className="opacity-0 group-hover:opacity-100 transition-opacity duration-250
                                     w-12 h-12 rounded-full bg-cinema-gold/90 flex items-center justify-center"
                          style={{ boxShadow: '0 4px 16px rgba(212, 160, 23, 0.35)' }}
                          whileHover={{ scale: 1.1 }}
                        >
                          <svg className="w-5 h-5 text-black ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                            <path d="M8 5v14l11-7z" />
                          </svg>
                        </motion.div>
                      </div>
                    </div>
                    <h3 className="text-white text-sm font-medium truncate group-hover:text-cinema-gold
                                   transition-colors duration-200">{album.name}</h3>
                    <p className="text-cinema-text-dim text-xs mt-0.5 truncate">{album.artist}</p>
                    {album.year && <p className="text-cinema-text-dim text-xs">{album.year}</p>}
                  </motion.div>
                ))}
                {albums.length === 0 && (
                  <div className="col-span-full">
                    <EmptyState message="No albums found." />
                  </div>
                )}
              </div>
            )}

            {/* Playlists tab */}
            {subTab === 'playlists' && (
              <div>
                <div className="flex items-center justify-between mb-4">
                  <span className="text-cinema-text-dim text-xs">{playlists.length} playlists</span>
                  <motion.button
                    onClick={() => setShowNewPlaylist(true)}
                    className="flex items-center gap-1.5 px-3 py-1.5 bg-cinema-surface hover:bg-cinema-card
                               rounded-lg text-sm text-cinema-text-secondary hover:text-white
                               border border-cinema-border hover:border-cinema-border-hover
                               transition-all duration-200"
                    whileTap={{ scale: 0.97 }}
                  >
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                    </svg>
                    New Playlist
                  </motion.button>
                </div>

                {/* New playlist form */}
                <AnimatePresence>
                  {showNewPlaylist && (
                    <motion.div
                      className="mb-4 p-4 bg-cinema-surface rounded-xl border border-cinema-border"
                      initial={{ opacity: 0, height: 0 }}
                      animate={{ opacity: 1, height: 'auto' }}
                      exit={{ opacity: 0, height: 0 }}
                      transition={{ duration: 0.2 }}
                    >
                      <div className="flex gap-3">
                        <input
                          type="text"
                          placeholder="Playlist name..."
                          value={newPlaylistName}
                          onChange={(e) => setNewPlaylistName(e.target.value)}
                          onKeyDown={(e) => { if (e.key === 'Enter') handleCreatePlaylist(); }}
                          className="flex-1 bg-cinema-card border border-cinema-border rounded-lg px-3 py-2
                                     text-sm text-white placeholder:text-cinema-text-dim
                                     focus:outline-none focus:border-cinema-gold/50"
                          autoFocus
                        />
                        <motion.button
                          onClick={handleCreatePlaylist}
                          className="px-4 py-2 bg-cinema-gold text-black rounded-lg text-sm font-semibold
                                     hover:bg-cinema-gold-hover transition-colors"
                          whileTap={{ scale: 0.97 }}
                        >
                          Create
                        </motion.button>
                        <motion.button
                          onClick={() => { setShowNewPlaylist(false); setNewPlaylistName(''); }}
                          className="px-3 py-2 text-cinema-text-secondary hover:text-white transition-colors"
                          whileTap={{ scale: 0.97 }}
                        >
                          Cancel
                        </motion.button>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>

                {/* Playlist list */}
                <div className="space-y-2">
                  {playlists.map((pl, i) => (
                    <motion.div
                      key={pl.id}
                      className="flex items-center gap-4 p-4 bg-cinema-surface/50 rounded-xl
                                 hover:bg-cinema-surface transition-all duration-200 group cursor-pointer
                                 ring-1 ring-white/[0.02] hover:ring-white/[0.06]"
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: i * 0.04, duration: 0.25 }}
                    >
                      <div className="w-14 h-14 rounded-lg bg-cinema-card flex items-center justify-center
                                      ring-1 ring-white/[0.06]">
                        <svg className="w-6 h-6 text-cinema-gold/60" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z" />
                        </svg>
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-white text-sm font-medium truncate group-hover:text-cinema-gold
                                      transition-colors duration-200">{pl.name}</p>
                        <p className="text-cinema-text-dim text-xs mt-0.5">
                          {pl.track_count || 0} tracks
                          {pl.description && ` · ${pl.description}`}
                        </p>
                      </div>
                      <motion.button
                        onClick={(e) => { e.stopPropagation(); handleDeletePlaylist(pl.id); }}
                        className="opacity-0 group-hover:opacity-100 w-8 h-8 rounded-full bg-cinema-card
                                   hover:bg-cinema-red/20 flex items-center justify-center transition-all duration-200"
                        whileTap={{ scale: 0.9 }}
                      >
                        <svg className="w-4 h-4 text-cinema-text-dim hover:text-cinema-red transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                        </svg>
                      </motion.button>
                    </motion.div>
                  ))}
                </div>

                {playlists.length === 0 && !showNewPlaylist && (
                  <EmptyState message="No playlists yet. Create one to get started." />
                )}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

// ─── Sub-components ───

function TrackCard({
  track,
  onPlay,
  onAlbumClick,
}: {
  track: MusicTrack;
  onPlay: () => void;
  onAlbumClick: (albumId: number) => void;
}) {
  const artUrl = track.album_id ? api.getMusicArtUrl(track.album_id) : null;

  return (
    <motion.div
      className="relative group cursor-pointer flex-shrink-0 w-[160px]"
      whileHover={{ scale: 1.04, y: -4 }}
      transition={{ duration: 0.25, ease: [0.4, 0, 0.2, 1] }}
      onClick={onPlay}
    >
      <div className="relative w-[160px] h-[160px] rounded-xl overflow-hidden bg-cinema-card
                      ring-1 ring-white/[0.04] group-hover:ring-white/[0.08]
                      transition-all duration-300
                      group-hover:shadow-xl group-hover:shadow-black/50">
        {artUrl ? (
          <img src={artUrl} alt={track.album} className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full flex items-center justify-center bg-cinema-surface">
            <svg className="w-10 h-10 text-cinema-text-dim/30" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9 19V6l12-3v13" />
            </svg>
          </div>
        )}

        <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent
                        opacity-0 group-hover:opacity-100 transition-opacity duration-250" />

        <div className="absolute inset-0 flex items-center justify-center">
          <motion.div
            className="opacity-0 group-hover:opacity-100 transition-opacity duration-250
                       w-12 h-12 bg-cinema-gold/95 rounded-full flex items-center justify-center
                       shadow-lg shadow-black/30"
            style={{ boxShadow: '0 4px 16px rgba(212, 160, 23, 0.35)' }}
            whileHover={{ scale: 1.12 }}
            whileTap={{ scale: 0.9 }}
          >
            <svg className="w-5 h-5 text-black ml-0.5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M8 5v14l11-7z" />
            </svg>
          </motion.div>
        </div>
      </div>

      <div className="mt-2 px-0.5">
        <h3 className="text-white text-sm font-medium truncate group-hover:text-cinema-gold transition-colors duration-200">
          {track.title}
        </h3>
        <p className="text-cinema-text-dim text-xs truncate mt-0.5">{track.artist}</p>
      </div>
    </motion.div>
  );
}

function EmptyState({ message }: { message: string }) {
  return (
    <div className="flex flex-col items-center justify-center py-20 text-cinema-text-dim">
      <svg className="w-16 h-16 mb-4 opacity-15" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z" />
      </svg>
      <p className="text-sm">{message}</p>
    </div>
  );
}
