import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { api } from '../api/client';
import { useAccounts } from '../hooks/useAccounts';
import type { BookItem } from '../api/types';

const FORMAT_COLORS: Record<string, string> = {
  EPUB: 'bg-blue-500',
  PDF: 'bg-red-500',
  MOBI: 'bg-orange-500',
  AZW3: 'bg-orange-500',
  CBZ: 'bg-purple-500',
  CBR: 'bg-purple-500',
  FB2: 'bg-green-500',
  DJVU: 'bg-teal-500',
};

function formatFileSize(bytes: number): string {
  if (bytes >= 1_073_741_824) return `${(bytes / 1_073_741_824).toFixed(1)} GB`;
  if (bytes >= 1_048_576) return `${Math.round(bytes / 1_048_576)} MB`;
  return `${Math.round(bytes / 1024)} KB`;
}

interface BookDetailViewProps {
  book: BookItem;
  onClose: () => void;
  onRead: () => void;
  onBookUpdated: () => void;
}

export default function BookDetailView({ book, onClose, onRead, onBookUpdated }: BookDetailViewProps) {
  const { currentAccount } = useAccounts();
  const [imgError, setImgError] = useState(false);
  const [showFullDescription, setShowFullDescription] = useState(false);
  const [localBook, setLocalBook] = useState(book);
  const [bookmarks, setBookmarks] = useState<{ id: number; page: number; note: string | null; created_at?: string }[]>([]);

  const coverUrl = api.bookCoverUrl(localBook.id);
  const fmtColor = FORMAT_COLORS[localBook.format] || 'bg-gray-500';

  useEffect(() => {
    setLocalBook(book);
    setImgError(false);
  }, [book]);

  useEffect(() => {
    if (currentAccount) {
      api.getBookBookmarks(currentAccount.id, book.id).then(setBookmarks).catch(() => {});
    }
  }, [book.id, currentAccount]);

  const handleToggleFavorite = async () => {
    if (!currentAccount) return;
    try {
      await api.toggleBookFavorite(currentAccount.id, localBook.id);
      setLocalBook((prev) => ({ ...prev, favorite: !prev.favorite }));
      onBookUpdated();
    } catch {}
  };

  const handleMarkFinished = async () => {
    if (!currentAccount) return;
    try {
      if (localBook.finished) {
        // Unmark finished by setting progress to current minus epsilon
        await api.updateBookProgress(currentAccount.id, localBook.id, Math.min(localBook.reading_progress, 0.9));
        setLocalBook((prev) => ({ ...prev, finished: false }));
      } else {
        await api.markBookFinished(currentAccount.id, localBook.id);
        setLocalBook((prev) => ({ ...prev, finished: true, reading_progress: 1.0 }));
      }
      onBookUpdated();
    } catch {}
  };

  const progressPercent = Math.round(localBook.reading_progress * 100);
  const pagesRead = localBook.page_count > 0 ? Math.round(localBook.page_count * localBook.reading_progress) : 0;

  const readButtonLabel = localBook.reading_progress > 0 && !localBook.finished
    ? 'Resume'
    : localBook.format === 'PDF'
      ? 'View PDF'
      : 'Read';

  return (
    <motion.div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      onClick={onClose}
    >
      <motion.div
        className="relative bg-cinema-card rounded-xl w-[700px] max-h-[85vh] overflow-hidden shadow-2xl border border-cinema-border flex flex-col"
        initial={{ scale: 0.92, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        exit={{ scale: 0.92, opacity: 0 }}
        transition={{ duration: 0.2 }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute top-3 right-3 z-10 w-8 h-8 rounded-full bg-white/10 backdrop-blur-md
                     flex items-center justify-center text-white hover:bg-white/20 transition-colors"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>

        {/* Scrollable content */}
        <div className="flex-1 overflow-y-auto">
          {/* Top section: cover + info */}
          <div className="flex gap-6 p-6">
            {/* Cover image */}
            <div className="w-[200px] h-[280px] flex-shrink-0 rounded-lg overflow-hidden shadow-xl">
              {!imgError ? (
                <img
                  src={coverUrl}
                  alt={localBook.title}
                  className="w-full h-full object-cover"
                  onError={() => setImgError(true)}
                />
              ) : (
                <div className={`w-full h-full flex flex-col items-center justify-center gap-3 bg-gradient-to-br from-white/5 to-cinema-surface`}>
                  <svg className="w-10 h-10 text-white/20" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M6 2a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8l-6-6H6zm7 1.5L18.5 9H13V3.5z" />
                  </svg>
                  <span className="text-white/40 text-xs text-center px-3 line-clamp-3">{localBook.title}</span>
                </div>
              )}
            </div>

            {/* Book info */}
            <div className="flex-1 min-w-0 flex flex-col">
              <h2 className="text-2xl font-bold text-white leading-tight pr-8">{localBook.title}</h2>

              {localBook.author && (
                <p className="text-cinema-text-secondary text-sm mt-1.5">{localBook.author}</p>
              )}

              {/* Badges */}
              <div className="flex items-center gap-2 mt-3 flex-wrap">
                {localBook.genre && (
                  <span className="bg-white/10 text-white/70 text-[10px] px-2 py-0.5 rounded">
                    {localBook.genre}
                  </span>
                )}
                <span className={`${fmtColor}/80 text-white text-[10px] font-bold px-2 py-0.5 rounded`}>
                  {localBook.format}
                </span>
                {localBook.year && (
                  <span className="text-cinema-text-dim text-xs">{localBook.year}</span>
                )}
              </div>

              {/* Reading progress */}
              {localBook.reading_progress > 0 && (
                <div className="mt-4">
                  <div className="w-full h-1.5 bg-white/10 rounded-full overflow-hidden">
                    <motion.div
                      className="h-full bg-cinema-gold rounded-full"
                      initial={{ width: 0 }}
                      animate={{ width: `${progressPercent}%` }}
                      transition={{ duration: 0.5, ease: 'easeOut' }}
                    />
                  </div>
                  <p className="text-cinema-text-dim text-[11px] mt-1">
                    {localBook.page_count > 0
                      ? `Page ${pagesRead} of ${localBook.page_count} (${progressPercent}%)`
                      : `${progressPercent}% complete`}
                  </p>
                </div>
              )}

              {/* Action buttons */}
              <div className="flex items-center gap-2.5 mt-5">
                {/* Read / Resume */}
                <button
                  onClick={() => {
                    onRead();
                  }}
                  className="flex items-center gap-2 px-5 py-2.5 bg-cinema-gold hover:bg-cinema-gold-hover
                             text-black font-semibold text-sm rounded-md transition-colors flex-1 justify-center"
                >
                  <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                  </svg>
                  {readButtonLabel}
                </button>

                {/* Mark finished */}
                <button
                  onClick={handleMarkFinished}
                  className={`flex items-center justify-center w-10 h-10 rounded-md transition-colors
                    ${localBook.finished
                      ? 'bg-green-500/20 text-green-400 hover:bg-green-500/30'
                      : 'bg-white/10 text-white hover:bg-white/15'}`}
                  title={localBook.finished ? 'Mark as unfinished' : 'Mark as finished'}
                >
                  <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                </button>

                {/* Favorite */}
                <button
                  onClick={handleToggleFavorite}
                  className={`flex items-center justify-center w-10 h-10 rounded-md transition-colors
                    ${localBook.favorite
                      ? 'bg-red-500/20 text-red-400 hover:bg-red-500/30'
                      : 'bg-white/10 text-white hover:bg-white/15'}`}
                  title={localBook.favorite ? 'Remove from favorites' : 'Add to favorites'}
                >
                  <svg className="w-5 h-5" fill={localBook.favorite ? 'currentColor' : 'none'} viewBox="0 0 24 24" stroke="currentColor" strokeWidth={localBook.favorite ? 0 : 2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                  </svg>
                </button>
              </div>
            </div>
          </div>

          {/* Description */}
          {localBook.description && (
            <div className="px-6 pb-4">
              <div className="pt-4 border-t border-cinema-border">
                <p className={`text-cinema-text-secondary text-sm leading-relaxed ${!showFullDescription ? 'line-clamp-4' : ''}`}>
                  {localBook.description}
                </p>
                {localBook.description.length > 200 && (
                  <button
                    onClick={() => setShowFullDescription(!showFullDescription)}
                    className="text-cinema-gold text-xs font-medium mt-1 hover:text-cinema-gold-hover transition-colors"
                  >
                    {showFullDescription ? 'Show Less' : 'Show More'}
                  </button>
                )}
              </div>
            </div>
          )}

          {/* Details grid */}
          <div className="px-6 pb-4">
            <div className="pt-4 border-t border-cinema-border">
              <div className="grid grid-cols-2 gap-y-2.5 gap-x-8 text-xs">
                {localBook.publisher && (
                  <>
                    <span className="text-cinema-text-dim">Publisher</span>
                    <span className="text-cinema-text-secondary">{localBook.publisher}</span>
                  </>
                )}
                {localBook.language && (
                  <>
                    <span className="text-cinema-text-dim">Language</span>
                    <span className="text-cinema-text-secondary">{localBook.language}</span>
                  </>
                )}
                {localBook.page_count > 0 && (
                  <>
                    <span className="text-cinema-text-dim">Pages</span>
                    <span className="text-cinema-text-secondary">{localBook.page_count}</span>
                  </>
                )}
                <span className="text-cinema-text-dim">Format</span>
                <span className="text-cinema-text-secondary">
                  {localBook.format} &middot; {formatFileSize(localBook.file_size)}
                </span>
                {localBook.date_added && (
                  <>
                    <span className="text-cinema-text-dim">Added</span>
                    <span className="text-cinema-text-secondary">
                      {new Date(localBook.date_added).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })}
                    </span>
                  </>
                )}
              </div>
            </div>
          </div>

          {/* Bookmarks */}
          {bookmarks.length > 0 && (
            <div className="px-6 pb-6">
              <div className="pt-4 border-t border-cinema-border">
                <h3 className="text-white text-sm font-semibold mb-3 flex items-center gap-2">
                  <svg className="w-4 h-4 text-cinema-gold" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" />
                  </svg>
                  Bookmarks
                </h3>
                <div className="space-y-1.5">
                  {bookmarks.map((bm) => (
                    <div
                      key={bm.id}
                      className="flex items-center gap-3 px-3 py-2 rounded-md bg-white/[0.03] text-xs"
                    >
                      <span className="text-cinema-gold font-semibold">Page {bm.page}</span>
                      {bm.note && (
                        <span className="text-cinema-text-secondary truncate flex-1">{bm.note}</span>
                      )}
                      {bm.created_at && (
                        <span className="text-cinema-text-dim ml-auto flex-shrink-0">
                          {new Date(bm.created_at).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
                        </span>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      </motion.div>
    </motion.div>
  );
}
