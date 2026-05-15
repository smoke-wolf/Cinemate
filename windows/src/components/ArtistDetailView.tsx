import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import type { MusicArtist, MusicTrack } from '../api/types';
import { api } from '../api/client';

interface ArtistDetailViewProps {
  artistName: string;
  onBack: () => void;
  onAlbumClick: (albumId: number) => void;
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

export default function ArtistDetailView({ artistName, onBack, onAlbumClick, onPlayTrack }: ArtistDetailViewProps) {
  const [artist, setArtist] = useState<MusicArtist | null>(null);
  const [allTracks, setAllTracks] = useState<MusicTrack[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAllTracks, setShowAllTracks] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);

    Promise.all([
      api.getMusicArtistDetail(artistName),
      api.getMusicTracks({ artist: artistName, limit: 200 }),
    ]).then(([artistData, tracksData]) => {
      if (!cancelled) {
        setArtist(artistData);
        setAllTracks(tracksData.items);
        setLoading(false);
      }
    }).catch(() => {
      if (!cancelled) setLoading(false);
    });

    return () => { cancelled = true; };
  }, [artistName]);

  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-cinema-gold/30 border-t-cinema-gold rounded-full animate-spin" />
      </div>
    );
  }

  if (!artist) {
    return (
      <div className="h-full flex flex-col items-center justify-center text-cinema-text-dim">
        <p>Artist not found</p>
        <button onClick={onBack} className="mt-4 text-cinema-gold text-sm hover:underline">Go back</button>
      </div>
    );
  }

  const albums = artist.albums || [];
  const displayedTracks = showAllTracks ? allTracks : allTracks.slice(0, 5);
  const hue = artistName.split('').reduce((a, c) => a + c.charCodeAt(0), 0) % 360;

  return (
    <div className="h-full overflow-y-auto">
      {/* Header */}
      <div className="relative px-8 pt-8 pb-6">
        <div className="absolute inset-0 overflow-hidden">
          <div
            className="w-full h-full opacity-20 blur-3xl"
            style={{ background: `linear-gradient(135deg, hsl(${hue}, 50%, 25%), hsl(${(hue + 80) % 360}, 40%, 15%))` }}
          />
          <div className="absolute inset-0 bg-gradient-to-b from-cinema-bg/50 via-cinema-bg/85 to-cinema-bg" />
        </div>

        <div className="relative flex items-end gap-6">
          {/* Back button */}
          <motion.button
            onClick={onBack}
            className="absolute -left-1 -top-1 w-8 h-8 rounded-full bg-cinema-surface/80 hover:bg-cinema-border
                       flex items-center justify-center transition-all duration-200 z-10"
            whileHover={{ scale: 1.1 }}
            whileTap={{ scale: 0.9 }}
          >
            <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </motion.button>

          {/* Artist avatar */}
          <motion.div
            className="w-40 h-40 rounded-full overflow-hidden bg-cinema-surface flex-shrink-0
                       shadow-2xl shadow-black/60 ring-2 ring-white/[0.08] ml-8
                       flex items-center justify-center"
            style={{ background: `linear-gradient(135deg, hsl(${hue}, 40%, 18%), hsl(${(hue + 60) % 360}, 50%, 28%))` }}
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.4 }}
          >
            <svg className="w-16 h-16 text-white/20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
            </svg>
          </motion.div>

          <motion.div
            className="flex flex-col justify-end py-2"
            initial={{ opacity: 0, x: -10 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.1, duration: 0.4 }}
          >
            <span className="text-cinema-text-dim text-xs uppercase tracking-wider font-semibold mb-1">Artist</span>
            <h1 className="text-white text-3xl font-bold mb-2">{artist.artist}</h1>
            <div className="flex items-center gap-2 text-sm text-cinema-text-secondary">
              <span>{artist.album_count} albums</span>
              <span className="w-1 h-1 rounded-full bg-cinema-text-dim" />
              <span>{artist.track_count} tracks</span>
              <span className="w-1 h-1 rounded-full bg-cinema-text-dim" />
              <span>{formatTotalDuration(artist.total_duration)}</span>
            </div>

            {/* Play all */}
            <motion.button
              onClick={() => { if (allTracks.length > 0) onPlayTrack(allTracks[0], allTracks); }}
              className="mt-4 flex items-center gap-2 px-5 py-2.5 bg-cinema-gold rounded-full text-black
                         text-sm font-semibold hover:bg-cinema-gold-hover transition-colors duration-200 w-fit"
              whileHover={{ scale: 1.03 }}
              whileTap={{ scale: 0.97 }}
              style={{ boxShadow: '0 4px 16px rgba(212, 160, 23, 0.3)' }}
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z" />
              </svg>
              Play All
            </motion.button>
          </motion.div>
        </div>
      </div>

      <div className="px-8 pb-32">
        {/* Popular tracks */}
        {allTracks.length > 0 && (
          <div className="mb-8">
            <h2 className="text-white text-lg font-semibold mb-3">Popular</h2>
            {displayedTracks.map((track, i) => (
              <motion.div
                key={track.id}
                className="flex items-center gap-4 px-4 py-2.5 rounded-lg group cursor-pointer
                           hover:bg-white/[0.04] transition-all duration-150"
                initial={{ opacity: 0, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.03, duration: 0.2 }}
                onClick={() => onPlayTrack(track, allTracks)}
              >
                <span className="w-6 text-right text-cinema-text-dim text-sm tabular-nums group-hover:hidden">
                  {i + 1}
                </span>
                <span className="w-6 text-right hidden group-hover:block">
                  <svg className="w-4 h-4 text-cinema-gold ml-auto" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M8 5v14l11-7z" />
                  </svg>
                </span>
                {/* Mini album art */}
                <div className="w-10 h-10 rounded bg-cinema-surface overflow-hidden flex-shrink-0 ring-1 ring-white/[0.04]">
                  {track.album_id ? (
                    <img src={api.getMusicArtUrl(track.album_id)} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center">
                      <svg className="w-4 h-4 text-cinema-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 19V6l12-3v13" />
                      </svg>
                    </div>
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-white text-sm truncate group-hover:text-cinema-gold transition-colors duration-150">
                    {track.title}
                  </p>
                  <p className="text-cinema-text-dim text-xs truncate">{track.album}</p>
                </div>
                <span className="text-cinema-text-dim text-sm tabular-nums">{formatDuration(track.duration)}</span>
              </motion.div>
            ))}
            {allTracks.length > 5 && (
              <button
                onClick={() => setShowAllTracks(!showAllTracks)}
                className="mt-2 px-4 text-cinema-text-secondary text-sm font-medium hover:text-white
                           transition-colors duration-200"
              >
                {showAllTracks ? 'Show less' : `Show all ${allTracks.length} tracks`}
              </button>
            )}
          </div>
        )}

        {/* Albums */}
        {albums.length > 0 && (
          <div>
            <h2 className="text-white text-lg font-semibold mb-4">Albums</h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-5">
              {albums.map((album, i) => (
                <motion.div
                  key={album.album_id}
                  className="group cursor-pointer"
                  initial={{ opacity: 0, y: 15 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: i * 0.04, duration: 0.3 }}
                  whileHover={{ scale: 1.03, y: -4 }}
                  onClick={() => onAlbumClick(album.album_id)}
                >
                  <div className="relative aspect-square rounded-xl overflow-hidden bg-cinema-surface
                                  ring-1 ring-white/[0.04] group-hover:ring-white/[0.08]
                                  group-hover:shadow-xl group-hover:shadow-black/40
                                  transition-all duration-300 mb-2">
                    <img
                      src={api.getMusicArtUrl(album.album_id)}
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
                  <h3 className="text-white text-sm font-medium truncate group-hover:text-cinema-gold transition-colors duration-200">
                    {album.name}
                  </h3>
                  <p className="text-cinema-text-dim text-xs mt-0.5">
                    {album.year || ''}{album.year && album.tracks ? ' · ' : ''}{album.tracks ? `${album.tracks} tracks` : ''}
                  </p>
                </motion.div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
