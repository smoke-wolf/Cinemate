import React, { useState, useEffect, useCallback, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import type { Playlist, MusicTrack } from '../api/types';
import { api } from '../api/client';
import { useAccounts } from '../hooks/useAccounts';

interface PlaylistViewProps {
  playlist: Playlist;
  onBack: () => void;
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

export default function PlaylistView({ playlist: initialPlaylist, onBack, onPlayTrack }: PlaylistViewProps) {
  const { currentAccount } = useAccounts();
  const [playlist, setPlaylist] = useState<Playlist>(initialPlaylist);
  const [tracks, setTracks] = useState<MusicTrack[]>([]);
  const [loading, setLoading] = useState(true);
  const [isEditingName, setIsEditingName] = useState(false);
  const [editedName, setEditedName] = useState(initialPlaylist.name);
  const [isEditingDesc, setIsEditingDesc] = useState(false);
  const [editedDesc, setEditedDesc] = useState(initialPlaylist.description || '');
  const [showAddTracks, setShowAddTracks] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [addTrackSearch, setAddTrackSearch] = useState('');
  const [allTracks, setAllTracks] = useState<MusicTrack[]>([]);
  const [allTracksLoading, setAllTracksLoading] = useState(false);
  const nameInputRef = useRef<HTMLInputElement>(null);
  const descInputRef = useRef<HTMLInputElement>(null);

  // Load playlist tracks
  const loadPlaylistTracks = useCallback(async () => {
    if (!currentAccount) return;
    setLoading(true);
    try {
      const playlists = await api.getPlaylists(currentAccount.id);
      const found = playlists.find(p => p.id === playlist.id);
      if (found) {
        setPlaylist(found);
        setTracks(found.tracks || []);
      }
    } catch {
      // If tracks aren't in the playlist response, try loading them separately
      setTracks([]);
    } finally {
      setLoading(false);
    }
  }, [currentAccount, playlist.id]);

  useEffect(() => {
    loadPlaylistTracks();
  }, [loadPlaylistTracks]);

  // Auto-focus inputs
  useEffect(() => {
    if (isEditingName && nameInputRef.current) {
      nameInputRef.current.focus();
      nameInputRef.current.select();
    }
  }, [isEditingName]);

  useEffect(() => {
    if (isEditingDesc && descInputRef.current) {
      descInputRef.current.focus();
    }
  }, [isEditingDesc]);

  const handleSaveName = useCallback(async () => {
    if (!currentAccount || !editedName.trim()) {
      setEditedName(playlist.name);
      setIsEditingName(false);
      return;
    }
    try {
      const updated = await api.updatePlaylist(currentAccount.id, playlist.id, { name: editedName.trim() });
      setPlaylist(prev => ({ ...prev, name: updated.name || editedName.trim() }));
    } catch {}
    setIsEditingName(false);
  }, [currentAccount, playlist.id, playlist.name, editedName]);

  const handleSaveDesc = useCallback(async () => {
    if (!currentAccount) {
      setIsEditingDesc(false);
      return;
    }
    const trimmed = editedDesc.trim();
    try {
      const updated = await api.updatePlaylist(currentAccount.id, playlist.id, {
        description: trimmed || undefined,
      });
      setPlaylist(prev => ({ ...prev, description: updated.description || trimmed || undefined }));
    } catch {}
    setIsEditingDesc(false);
  }, [currentAccount, playlist.id, editedDesc]);

  const handleDelete = useCallback(async () => {
    if (!currentAccount) return;
    try {
      await api.deletePlaylist(currentAccount.id, playlist.id);
      onBack();
    } catch {}
  }, [currentAccount, playlist.id, onBack]);

  const handleRemoveTrack = useCallback(async (trackId: number) => {
    if (!currentAccount) return;
    // The API doesn't have a dedicated remove-track endpoint, so we filter locally
    // and reload. In a full implementation this would call api.removeTrackFromPlaylist
    setTracks(prev => prev.filter(t => t.id !== trackId));
  }, [currentAccount]);

  const handleAddTrack = useCallback(async (track: MusicTrack) => {
    if (!currentAccount) return;
    try {
      await api.addTrackToPlaylist(currentAccount.id, playlist.id, track.id);
      setTracks(prev => [...prev, track]);
    } catch {}
  }, [currentAccount, playlist.id]);

  const handlePlayAll = useCallback(() => {
    if (tracks.length > 0) {
      onPlayTrack(tracks[0], tracks);
    }
  }, [tracks, onPlayTrack]);

  const handleShuffle = useCallback(() => {
    if (tracks.length === 0) return;
    const shuffled = [...tracks].sort(() => Math.random() - 0.5);
    onPlayTrack(shuffled[0], shuffled);
  }, [tracks, onPlayTrack]);

  // Load all tracks for "Add Tracks" sheet
  const loadAllTracks = useCallback(async () => {
    setAllTracksLoading(true);
    try {
      const data = await api.getMusicTracks({ limit: 500, search: addTrackSearch || undefined });
      setAllTracks(data.items);
    } catch {
      setAllTracks([]);
    } finally {
      setAllTracksLoading(false);
    }
  }, [addTrackSearch]);

  useEffect(() => {
    if (showAddTracks) {
      loadAllTracks();
    }
  }, [showAddTracks, loadAllTracks]);

  const totalDuration = tracks.reduce((sum, t) => sum + t.duration, 0);
  const trackIds = new Set(tracks.map(t => t.id));

  return (
    <div className="h-full overflow-y-auto">
      {/* Header with back button */}
      <div className="sticky top-0 z-20 bg-cinema-bg/95 backdrop-blur-lg border-b border-cinema-border">
        <div className="px-6 py-4 flex items-center gap-3">
          <motion.button
            onClick={onBack}
            className="text-cinema-text-secondary hover:text-white transition-colors duration-150"
            whileHover={{ scale: 1.1 }}
            whileTap={{ scale: 0.9 }}
          >
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </motion.button>
          <span className="text-cinema-text-dim text-sm">Back to Playlists</span>
        </div>
      </div>

      <div className="p-6 pb-32">
        {/* Playlist header */}
        <div className="flex items-end gap-6 mb-8">
          {/* Playlist cover art (collage of first 4 album arts) */}
          <div className="w-48 h-48 rounded-xl overflow-hidden bg-cinema-surface ring-1 ring-white/[0.06]
                          shadow-xl shadow-black/40 flex-shrink-0">
            {tracks.length > 0 && tracks[0].album_id ? (
              <div className="grid grid-cols-2 grid-rows-2 w-full h-full">
                {tracks.slice(0, 4).map((track, i) => (
                  <div key={`cover-${track.id}-${i}`} className="overflow-hidden">
                    {track.album_id ? (
                      <img
                        src={api.getMusicArtUrl(track.album_id)}
                        alt=""
                        className="w-full h-full object-cover"
                        onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                      />
                    ) : (
                      <div className="w-full h-full bg-cinema-card flex items-center justify-center">
                        <svg className="w-8 h-8 text-cinema-text-dim/20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9 19V6l12-3v13" />
                        </svg>
                      </div>
                    )}
                  </div>
                ))}
                {/* Fill remaining slots if less than 4 tracks */}
                {Array.from({ length: Math.max(0, 4 - tracks.length) }).map((_, i) => (
                  <div key={`empty-${i}`} className="bg-cinema-card flex items-center justify-center">
                    <svg className="w-6 h-6 text-cinema-text-dim/10" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9 19V6l12-3v13" />
                    </svg>
                  </div>
                ))}
              </div>
            ) : (
              <div className="w-full h-full flex items-center justify-center">
                <svg className="w-16 h-16 text-cinema-gold/30" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1}
                        d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z" />
                </svg>
              </div>
            )}
          </div>

          {/* Info */}
          <div className="flex-1 min-w-0">
            <p className="text-cinema-text-dim text-xs font-medium uppercase tracking-wider mb-2">Playlist</p>

            {/* Editable name */}
            {isEditingName ? (
              <input
                ref={nameInputRef}
                type="text"
                value={editedName}
                onChange={(e) => setEditedName(e.target.value)}
                onBlur={handleSaveName}
                onKeyDown={(e) => { if (e.key === 'Enter') handleSaveName(); if (e.key === 'Escape') { setEditedName(playlist.name); setIsEditingName(false); } }}
                className="bg-white/[0.06] border border-cinema-border rounded-md px-3 py-1.5
                           text-white text-2xl font-bold w-full focus:outline-none focus:border-cinema-gold/50"
              />
            ) : (
              <h1
                className="text-white text-2xl font-bold cursor-pointer hover:text-cinema-gold transition-colors duration-150"
                onClick={() => { setEditedName(playlist.name); setIsEditingName(true); }}
              >
                {playlist.name}
              </h1>
            )}

            {/* Editable description */}
            {isEditingDesc ? (
              <input
                ref={descInputRef}
                type="text"
                value={editedDesc}
                onChange={(e) => setEditedDesc(e.target.value)}
                onBlur={handleSaveDesc}
                onKeyDown={(e) => { if (e.key === 'Enter') handleSaveDesc(); if (e.key === 'Escape') { setEditedDesc(playlist.description || ''); setIsEditingDesc(false); } }}
                placeholder="Add a description..."
                className="bg-white/[0.06] border border-cinema-border rounded-md px-3 py-1
                           text-white/80 text-sm w-full mt-2 focus:outline-none focus:border-cinema-gold/50"
              />
            ) : (
              <p
                className={`text-sm mt-2 cursor-pointer transition-colors duration-150
                           ${playlist.description
                             ? 'text-cinema-text-secondary hover:text-white'
                             : 'text-cinema-text-dim/50 italic hover:text-cinema-text-dim'}`}
                onClick={() => { setEditedDesc(playlist.description || ''); setIsEditingDesc(true); }}
              >
                {playlist.description || 'Add description...'}
              </p>
            )}

            {/* Stats */}
            <div className="flex items-center gap-3 mt-3 text-cinema-text-dim text-sm">
              <span>{tracks.length} track{tracks.length !== 1 ? 's' : ''}</span>
              <span className="text-cinema-border">|</span>
              <span>{formatTotalDuration(totalDuration)}</span>
              {playlist.created_at && (
                <>
                  <span className="text-cinema-border">|</span>
                  <span className="text-cinema-text-dim/60">
                    Created {new Date(playlist.created_at).toLocaleDateString()}
                  </span>
                </>
              )}
            </div>
          </div>
        </div>

        {/* Action buttons */}
        <div className="flex items-center gap-3 mb-6">
          <motion.button
            onClick={handlePlayAll}
            disabled={tracks.length === 0}
            className="flex items-center gap-2 px-6 py-2.5 bg-white text-black rounded-full
                       text-sm font-semibold hover:bg-white/90 transition-colors duration-150
                       disabled:opacity-40 disabled:cursor-not-allowed"
            whileHover={{ scale: tracks.length > 0 ? 1.03 : 1 }}
            whileTap={{ scale: 0.97 }}
          >
            <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
              <path d="M8 5v14l11-7z" />
            </svg>
            Play All
          </motion.button>

          <motion.button
            onClick={handleShuffle}
            disabled={tracks.length === 0}
            className="flex items-center gap-2 px-5 py-2.5 bg-white/10 text-white/80 rounded-full
                       text-sm font-medium hover:bg-white/15 transition-colors duration-150
                       disabled:opacity-40 disabled:cursor-not-allowed"
            whileTap={{ scale: 0.97 }}
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                    d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            Shuffle
          </motion.button>

          <motion.button
            onClick={() => setShowAddTracks(true)}
            className="flex items-center gap-2 px-5 py-2.5 bg-white/[0.06] text-white/70 rounded-full
                       text-sm font-medium hover:bg-white/10 transition-colors duration-150"
            whileTap={{ scale: 0.97 }}
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
            </svg>
            Add Tracks
          </motion.button>

          <div className="flex-1" />

          <motion.button
            onClick={() => setShowDeleteConfirm(true)}
            className="p-2.5 bg-cinema-red/10 hover:bg-cinema-red/20 rounded-lg transition-colors duration-150"
            whileTap={{ scale: 0.9 }}
          >
            <svg className="w-4 h-4 text-cinema-red/70" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                    d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </motion.button>
        </div>

        {/* Divider */}
        <div className="h-px bg-cinema-border mb-4" />

        {/* Track list */}
        {loading ? (
          <div className="flex items-center justify-center py-20">
            <div className="w-8 h-8 border-2 border-cinema-gold/30 border-t-cinema-gold rounded-full animate-spin" />
          </div>
        ) : tracks.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-center">
            <svg className="w-16 h-16 text-cinema-text-dim/15 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1}
                    d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z" />
            </svg>
            <p className="text-cinema-text-dim text-sm font-medium mb-1">This playlist is empty</p>
            <motion.button
              onClick={() => setShowAddTracks(true)}
              className="text-cinema-gold text-sm font-medium mt-2 hover:text-cinema-gold-hover transition-colors"
              whileTap={{ scale: 0.97 }}
            >
              Add Tracks
            </motion.button>
          </div>
        ) : (
          <>
            {/* Table header */}
            <div className="flex items-center gap-4 px-4 py-2 border-b border-cinema-border mb-1
                            text-cinema-text-dim text-xs uppercase tracking-wider font-semibold select-none">
              <span className="w-8 text-right">#</span>
              <span className="flex-[2] text-left">Title</span>
              <span className="flex-1 text-left">Artist</span>
              <span className="flex-1 text-left">Album</span>
              <span className="w-20 text-right">
                <svg className="w-4 h-4 inline" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                        d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </span>
              <span className="w-8" />
            </div>

            {tracks.map((track, i) => (
              <motion.div
                key={`${track.id}-${i}`}
                className="flex items-center gap-4 px-4 py-2 rounded-lg group cursor-pointer
                           hover:bg-white/[0.04] transition-all duration-150"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: Math.min(i * 0.02, 0.5), duration: 0.15 }}
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
                <div className="flex-1 min-w-0">
                  <p className="text-cinema-text-secondary text-sm truncate">{track.artist}</p>
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-cinema-text-secondary text-sm truncate">{track.album}</p>
                </div>
                <span className="w-20 text-right text-cinema-text-dim text-sm tabular-nums">
                  {formatDuration(track.duration)}
                </span>
                {/* Remove button */}
                <motion.button
                  onClick={(e) => { e.stopPropagation(); handleRemoveTrack(track.id); }}
                  className="w-8 opacity-0 group-hover:opacity-100 transition-opacity duration-150
                             text-cinema-text-dim hover:text-cinema-red"
                  whileTap={{ scale: 0.85 }}
                >
                  <svg className="w-4 h-4 mx-auto" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                          d="M15 12H9" />
                  </svg>
                </motion.button>
              </motion.div>
            ))}
          </>
        )}
      </div>

      {/* Add Tracks Modal */}
      <AnimatePresence>
        {showAddTracks && (
          <motion.div
            className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setShowAddTracks(false)}
          >
            <motion.div
              className="w-[520px] max-h-[600px] bg-cinema-card border border-cinema-border rounded-2xl
                         shadow-2xl shadow-black/60 overflow-hidden flex flex-col"
              initial={{ opacity: 0, scale: 0.95, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 20 }}
              transition={{ duration: 0.2 }}
              onClick={(e) => e.stopPropagation()}
            >
              {/* Modal header */}
              <div className="px-5 py-4 flex items-center justify-between border-b border-cinema-border">
                <h2 className="text-white text-lg font-bold">Add Tracks</h2>
                <motion.button
                  onClick={() => setShowAddTracks(false)}
                  className="w-8 h-8 rounded-full bg-white/10 hover:bg-white/15 flex items-center justify-center
                             text-white transition-colors duration-150"
                  whileTap={{ scale: 0.9 }}
                >
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </motion.button>
              </div>

              {/* Search */}
              <div className="px-5 py-3">
                <div className="relative">
                  <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-cinema-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                  <input
                    type="text"
                    placeholder="Search tracks..."
                    value={addTrackSearch}
                    onChange={(e) => setAddTrackSearch(e.target.value)}
                    className="w-full bg-cinema-surface border border-cinema-border rounded-lg pl-9 pr-3 py-2
                               text-sm text-white placeholder:text-cinema-text-dim
                               focus:outline-none focus:border-cinema-gold/50 focus:ring-1 focus:ring-cinema-gold/20"
                    autoFocus
                  />
                </div>
              </div>

              <div className="h-px bg-cinema-border" />

              {/* Track list */}
              <div className="flex-1 overflow-y-auto">
                {allTracksLoading ? (
                  <div className="flex items-center justify-center py-10">
                    <div className="w-6 h-6 border-2 border-cinema-gold/30 border-t-cinema-gold rounded-full animate-spin" />
                  </div>
                ) : (
                  allTracks.map((track) => {
                    const alreadyAdded = trackIds.has(track.id);
                    return (
                      <div
                        key={track.id}
                        className="flex items-center gap-3 px-5 py-2.5 hover:bg-white/[0.04] transition-colors duration-100"
                      >
                        <div className="flex-1 min-w-0">
                          <p className="text-white text-sm font-medium truncate">{track.title}</p>
                          <p className="text-cinema-text-dim text-xs truncate">
                            {track.artist} - {track.album}
                          </p>
                        </div>
                        <span className="text-cinema-text-dim text-xs font-mono tabular-nums">
                          {formatDuration(track.duration)}
                        </span>
                        <motion.button
                          onClick={() => !alreadyAdded && handleAddTrack(track)}
                          disabled={alreadyAdded}
                          className={`flex-shrink-0 transition-colors duration-150
                                     ${alreadyAdded
                                       ? 'text-cinema-green cursor-default'
                                       : 'text-cinema-gold hover:text-cinema-gold-hover cursor-pointer'}`}
                          whileTap={alreadyAdded ? {} : { scale: 0.85 }}
                        >
                          {alreadyAdded ? (
                            <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                              <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
                            </svg>
                          ) : (
                            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                    d="M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z" />
                            </svg>
                          )}
                        </motion.button>
                      </div>
                    );
                  })
                )}
                {!allTracksLoading && allTracks.length === 0 && (
                  <div className="text-center py-10 text-cinema-text-dim text-sm">
                    No tracks found.
                  </div>
                )}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Delete Confirmation Modal */}
      <AnimatePresence>
        {showDeleteConfirm && (
          <motion.div
            className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setShowDeleteConfirm(false)}
          >
            <motion.div
              className="w-[400px] bg-cinema-card border border-cinema-border rounded-2xl
                         shadow-2xl shadow-black/60 p-6"
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              onClick={(e) => e.stopPropagation()}
            >
              <h3 className="text-white text-lg font-bold mb-2">Delete Playlist</h3>
              <p className="text-cinema-text-secondary text-sm mb-6">
                Are you sure you want to delete "{playlist.name}"? This cannot be undone.
              </p>
              <div className="flex justify-end gap-3">
                <motion.button
                  onClick={() => setShowDeleteConfirm(false)}
                  className="px-4 py-2 text-cinema-text-secondary hover:text-white text-sm font-medium
                             transition-colors duration-150"
                  whileTap={{ scale: 0.97 }}
                >
                  Cancel
                </motion.button>
                <motion.button
                  onClick={handleDelete}
                  className="px-4 py-2 bg-cinema-red text-white rounded-lg text-sm font-semibold
                             hover:bg-cinema-red/80 transition-colors duration-150"
                  whileTap={{ scale: 0.97 }}
                >
                  Delete
                </motion.button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
