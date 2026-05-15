import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import type { MusicAlbum, MusicTrack } from '../api/types';
import { api } from '../api/client';

interface AlbumDetailViewProps {
  albumId: number;
  onBack: () => void;
  onPlayTrack: (track: MusicTrack, queue: MusicTrack[]) => void;
  onArtistClick: (artistName: string) => void;
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

export default function AlbumDetailView({ albumId, onBack, onPlayTrack, onArtistClick }: AlbumDetailViewProps) {
  const [album, setAlbum] = useState<MusicAlbum | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    api.getMusicAlbumDetail(albumId).then((data) => {
      if (!cancelled) {
        setAlbum(data);
        setLoading(false);
      }
    }).catch(() => {
      if (!cancelled) setLoading(false);
    });
    return () => { cancelled = true; };
  }, [albumId]);

  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-cinema-gold/30 border-t-cinema-gold rounded-full animate-spin" />
      </div>
    );
  }

  if (!album) {
    return (
      <div className="h-full flex flex-col items-center justify-center text-cinema-text-dim">
        <p>Album not found</p>
        <button onClick={onBack} className="mt-4 text-cinema-gold text-sm hover:underline">Go back</button>
      </div>
    );
  }

  const tracks = album.tracks || [];
  const totalDuration = tracks.reduce((sum, t) => sum + (t.duration || 0), 0);
  const artUrl = api.getMusicArtUrl(album.id);

  return (
    <div className="h-full overflow-y-auto">
      {/* Header */}
      <div className="relative px-8 pt-8 pb-6">
        {/* Background blur from album art */}
        <div className="absolute inset-0 overflow-hidden">
          <img src={artUrl} alt="" className="w-full h-full object-cover opacity-15 blur-3xl scale-150" />
          <div className="absolute inset-0 bg-gradient-to-b from-cinema-bg/60 via-cinema-bg/90 to-cinema-bg" />
        </div>

        <div className="relative flex items-start gap-6">
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

          {/* Album art */}
          <motion.div
            className="w-48 h-48 rounded-xl overflow-hidden bg-cinema-surface flex-shrink-0
                       shadow-2xl shadow-black/60 ring-1 ring-white/[0.06] ml-8"
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.4, ease: [0.4, 0, 0.2, 1] }}
          >
            <img src={artUrl} alt={album.name} className="w-full h-full object-cover"
                 onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }} />
            <div className="w-full h-full flex items-center justify-center absolute inset-0 -z-10">
              <svg className="w-16 h-16 text-cinema-text-dim/30" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z" />
              </svg>
            </div>
          </motion.div>

          {/* Album info */}
          <motion.div
            className="flex flex-col justify-end min-h-[12rem] py-2"
            initial={{ opacity: 0, x: -10 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.1, duration: 0.4 }}
          >
            <span className="text-cinema-text-dim text-xs uppercase tracking-wider font-semibold mb-1">Album</span>
            <h1 className="text-white text-3xl font-bold mb-2">{album.name}</h1>
            <div className="flex items-center gap-2 text-sm">
              <button
                onClick={() => onArtistClick(album.artist)}
                className="text-cinema-text-secondary hover:text-cinema-gold transition-colors duration-200 font-medium"
              >
                {album.artist}
              </button>
              {album.year && (
                <>
                  <span className="w-1 h-1 rounded-full bg-cinema-text-dim" />
                  <span className="text-cinema-text-dim">{album.year}</span>
                </>
              )}
              <span className="w-1 h-1 rounded-full bg-cinema-text-dim" />
              <span className="text-cinema-text-dim">{tracks.length} tracks</span>
              <span className="w-1 h-1 rounded-full bg-cinema-text-dim" />
              <span className="text-cinema-text-dim">{formatTotalDuration(totalDuration)}</span>
            </div>

            {/* Play all button */}
            <motion.button
              onClick={() => { if (tracks.length > 0) onPlayTrack(tracks[0], tracks); }}
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

      {/* Track list */}
      <div className="px-8 pb-32">
        {/* Header row */}
        <div className="flex items-center gap-4 px-4 py-2 border-b border-cinema-border mb-1
                        text-cinema-text-dim text-xs uppercase tracking-wider font-semibold">
          <span className="w-8 text-right">#</span>
          <span className="flex-1">Title</span>
          <span className="w-20 text-right">
            <svg className="w-4 h-4 inline" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </span>
        </div>

        {tracks.map((track, i) => (
          <motion.div
            key={track.id}
            className="flex items-center gap-4 px-4 py-2.5 rounded-lg group cursor-pointer
                       hover:bg-white/[0.04] transition-all duration-150"
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.02, duration: 0.2 }}
            onClick={() => onPlayTrack(track, tracks)}
          >
            <span className="w-8 text-right text-cinema-text-dim text-sm tabular-nums font-mono
                            group-hover:hidden">
              {track.track_number || i + 1}
            </span>
            <span className="w-8 text-right hidden group-hover:block">
              <svg className="w-4 h-4 text-cinema-gold ml-auto" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z" />
              </svg>
            </span>
            <div className="flex-1 min-w-0">
              <p className="text-white text-sm truncate group-hover:text-cinema-gold transition-colors duration-150">
                {track.title}
              </p>
              {track.artist !== album.artist && (
                <p className="text-cinema-text-dim text-xs truncate">{track.artist}</p>
              )}
            </div>
            <span className="w-20 text-right text-cinema-text-dim text-sm tabular-nums">
              {formatDuration(track.duration)}
            </span>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
