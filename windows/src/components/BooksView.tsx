import React, { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { api } from '../api/client';
import type { BookItem } from '../api/types';

type BookSubView = 'all' | 'reading' | 'finished' | 'authors';
type BookSort = 'date_added' | 'title' | 'author' | 'year';

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

function BookCard({ book, onSelect }: { book: BookItem; onSelect: () => void }) {
  const [hovered, setHovered] = useState(false);
  const [imgError, setImgError] = useState(false);
  const coverUrl = api.bookCoverUrl(book.id);
  const fmtColor = FORMAT_COLORS[book.format] || 'bg-gray-500';

  return (
    <motion.div
      className="group cursor-pointer"
      onClick={onSelect}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      whileHover={{ scale: 1.04 }}
      transition={{ duration: 0.15 }}
    >
      <div className="relative aspect-[0.7] rounded-lg overflow-hidden shadow-lg">
        {!imgError ? (
          <img
            src={coverUrl}
            alt={book.title}
            className="w-full h-full object-cover"
            onError={() => setImgError(true)}
          />
        ) : (
          <div className={`w-full h-full flex flex-col items-center justify-center gap-2 ${fmtColor}/20 bg-cinema-card`}>
            <svg className="w-10 h-10 text-white/20" fill="currentColor" viewBox="0 0 24 24">
              <path d="M6 2a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8l-6-6H6zm7 1.5L18.5 9H13V3.5z" />
            </svg>
            <span className="text-white/40 text-xs text-center px-2 line-clamp-2">{book.title}</span>
          </div>
        )}

        {/* Format badge */}
        <div className="absolute top-2 right-2 flex items-center gap-1">
          <span className={`${fmtColor}/90 text-white text-[9px] font-bold px-1.5 py-0.5 rounded`}>
            {book.format}
          </span>
          {book.finished && (
            <span className="bg-green-500/90 text-white text-[10px] rounded-full w-4 h-4 flex items-center justify-center">
              ✓
            </span>
          )}
        </div>

        {/* Reading progress bar */}
        {book.reading_progress > 0 && !book.finished && (
          <div className="absolute bottom-0 left-0 right-0 h-1">
            <div
              className="h-full bg-cinema-gold rounded-r"
              style={{ width: `${book.reading_progress * 100}%` }}
            />
          </div>
        )}

        {/* Hover overlay */}
        <AnimatePresence>
          {hovered && (
            <motion.div
              className="absolute inset-0 bg-black/60 flex flex-col items-center justify-center gap-3"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.15 }}
            >
              <span className="bg-cinema-gold text-black text-xs font-semibold px-4 py-1.5 rounded-md">
                View Details
              </span>
              {book.page_count > 0 && (
                <span className="text-white/60 text-[10px]">{book.page_count} pages</span>
              )}
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      <div className="mt-2 px-0.5">
        <p className="text-white text-xs font-medium line-clamp-2 leading-tight">{book.title}</p>
        <div className="flex items-center gap-1.5 mt-0.5">
          {book.author && (
            <span className="text-cinema-text-dim text-[11px] line-clamp-1">{book.author}</span>
          )}
          {book.year && (
            <span className="text-cinema-text-dim/50 text-[10px]">{book.year}</span>
          )}
        </div>
      </div>
    </motion.div>
  );
}

function BookDetailSheet({
  book,
  onClose,
}: {
  book: BookItem;
  onClose: () => void;
}) {
  const [imgError, setImgError] = useState(false);
  const coverUrl = api.bookCoverUrl(book.id);
  const fmtColor = FORMAT_COLORS[book.format] || 'bg-gray-500';

  return (
    <motion.div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      onClick={onClose}
    >
      <motion.div
        className="bg-cinema-card rounded-xl w-[640px] max-h-[80vh] overflow-y-auto shadow-2xl border border-cinema-border"
        initial={{ scale: 0.9, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        exit={{ scale: 0.9, opacity: 0 }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="p-6">
          <div className="flex gap-6">
            {/* Cover */}
            <div className="w-[180px] h-[250px] flex-shrink-0 rounded-lg overflow-hidden shadow-lg">
              {!imgError ? (
                <img
                  src={coverUrl}
                  alt={book.title}
                  className="w-full h-full object-cover"
                  onError={() => setImgError(true)}
                />
              ) : (
                <div className={`w-full h-full flex items-center justify-center ${fmtColor}/20 bg-cinema-surface`}>
                  <svg className="w-12 h-12 text-white/20" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M6 2a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8l-6-6H6z" />
                  </svg>
                </div>
              )}
            </div>

            {/* Info */}
            <div className="flex-1 min-w-0">
              <h2 className="text-xl font-bold text-white leading-tight">{book.title}</h2>
              {book.author && (
                <p className="text-cinema-text-secondary text-sm mt-1">{book.author}</p>
              )}

              <div className="flex items-center gap-2 mt-3 flex-wrap">
                <span className={`${fmtColor}/80 text-white text-[10px] font-bold px-2 py-0.5 rounded`}>
                  {book.format}
                </span>
                {book.genre && (
                  <span className="bg-white/10 text-white/70 text-[10px] px-2 py-0.5 rounded">
                    {book.genre}
                  </span>
                )}
                {book.year && (
                  <span className="text-cinema-text-dim text-xs">{book.year}</span>
                )}
              </div>

              {/* Progress */}
              {book.reading_progress > 0 && (
                <div className="mt-4">
                  <div className="w-full h-1.5 bg-white/10 rounded-full overflow-hidden">
                    <div
                      className="h-full bg-cinema-gold rounded-full transition-all"
                      style={{ width: `${book.reading_progress * 100}%` }}
                    />
                  </div>
                  <p className="text-cinema-text-dim text-[10px] mt-1">
                    {book.page_count > 0
                      ? `Page ${Math.round(book.page_count * book.reading_progress)} of ${book.page_count} (${Math.round(book.reading_progress * 100)}%)`
                      : `${Math.round(book.reading_progress * 100)}% complete`}
                  </p>
                </div>
              )}

              {/* Status badges */}
              <div className="flex items-center gap-3 mt-3">
                {book.finished && (
                  <span className="flex items-center gap-1 text-green-400 text-xs">
                    <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                    Finished
                  </span>
                )}
                {book.favorite && (
                  <span className="flex items-center gap-1 text-red-400 text-xs">
                    <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clipRule="evenodd" />
                    </svg>
                    Favorite
                  </span>
                )}
              </div>
            </div>
          </div>

          {/* Description */}
          {book.description && (
            <div className="mt-5 pt-5 border-t border-cinema-border">
              <p className="text-cinema-text-secondary text-sm leading-relaxed line-clamp-6">
                {book.description}
              </p>
            </div>
          )}

          {/* Details grid */}
          <div className="mt-5 pt-5 border-t border-cinema-border grid grid-cols-2 gap-y-2 gap-x-8 text-xs">
            {book.publisher && (
              <>
                <span className="text-cinema-text-dim">Publisher</span>
                <span className="text-cinema-text-secondary">{book.publisher}</span>
              </>
            )}
            {book.language && (
              <>
                <span className="text-cinema-text-dim">Language</span>
                <span className="text-cinema-text-secondary">{book.language}</span>
              </>
            )}
            {book.page_count > 0 && (
              <>
                <span className="text-cinema-text-dim">Pages</span>
                <span className="text-cinema-text-secondary">{book.page_count}</span>
              </>
            )}
            <span className="text-cinema-text-dim">Format</span>
            <span className="text-cinema-text-secondary">{book.format} · {formatFileSize(book.file_size)}</span>
          </div>
        </div>

        {/* Close button */}
        <div className="sticky bottom-0 p-4 border-t border-cinema-border bg-cinema-card/80 backdrop-blur-md">
          <button
            onClick={onClose}
            className="w-full py-2 text-sm text-cinema-text-secondary hover:text-white bg-cinema-surface hover:bg-cinema-card rounded-lg transition-colors"
          >
            Close
          </button>
        </div>
      </motion.div>
    </motion.div>
  );
}

export default function BooksView() {
  const [books, setBooks] = useState<BookItem[]>([]);
  const [subView, setSubView] = useState<BookSubView>('all');
  const [sort, setSort] = useState<BookSort>('date_added');
  const [search, setSearch] = useState('');
  const [formatFilter, setFormatFilter] = useState<string | null>(null);
  const [selectedBook, setSelectedBook] = useState<BookItem | null>(null);
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState<{ total_books: number; total_authors: number } | null>(null);

  const loadBooks = useCallback(async () => {
    try {
      setLoading(true);
      const params: { sort?: string; search?: string; format?: string } = { sort };
      if (search) params.search = search;
      if (formatFilter) params.format = formatFilter;
      const data = await api.getBooks(params);
      setBooks(data);
    } catch {
      setBooks([]);
    } finally {
      setLoading(false);
    }
  }, [sort, search, formatFilter]);

  useEffect(() => {
    loadBooks();
  }, [loadBooks]);

  useEffect(() => {
    api.getBookStats().then(setStats).catch(() => {});
  }, []);

  const filteredBooks = books.filter((b) => {
    if (subView === 'reading') return b.reading_progress > 0 && !b.finished;
    if (subView === 'finished') return b.finished;
    return true;
  });

  const SUB_VIEWS: { key: BookSubView; label: string }[] = [
    { key: 'all', label: 'All Books' },
    { key: 'reading', label: 'Currently Reading' },
    { key: 'finished', label: 'Finished' },
  ];

  const FORMATS = ['EPUB', 'PDF', 'MOBI', 'AZW3', 'CBZ', 'CBR', 'FB2', 'DJVU'];

  return (
    <div className="h-full flex flex-col">
      {/* Sub-nav */}
      <div className="flex items-center gap-1 px-6 py-3 border-b border-cinema-border bg-cinema-surface/50">
        {SUB_VIEWS.map((sv) => (
          <button
            key={sv.key}
            onClick={() => setSubView(sv.key)}
            className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${
              subView === sv.key
                ? 'bg-white/10 text-white'
                : 'text-cinema-text-dim hover:text-white'
            }`}
          >
            {sv.label}
          </button>
        ))}

        <div className="flex-1" />

        {/* Format filter */}
        <select
          value={formatFilter || ''}
          onChange={(e) => setFormatFilter(e.target.value || null)}
          className="bg-cinema-surface border border-cinema-border rounded-md px-2 py-1 text-[11px] text-cinema-text-secondary
                     focus:outline-none focus:border-cinema-gold/40 cursor-pointer"
        >
          <option value="">All Formats</option>
          {FORMATS.map((f) => (
            <option key={f} value={f}>{f}</option>
          ))}
        </select>

        {/* Sort */}
        <select
          value={sort}
          onChange={(e) => setSort(e.target.value as BookSort)}
          className="bg-cinema-surface border border-cinema-border rounded-md px-2 py-1 text-[11px] text-cinema-text-secondary
                     focus:outline-none focus:border-cinema-gold/40 cursor-pointer"
        >
          <option value="date_added">Recently Added</option>
          <option value="title">Title</option>
          <option value="author">Author</option>
          <option value="year">Year</option>
        </select>

        {/* Search */}
        <div className="relative">
          <svg className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-cinema-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <input
            type="text"
            placeholder="Search books..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="bg-cinema-surface border border-cinema-border rounded-md pl-8 pr-3 py-1 text-[11px] text-white
                       placeholder:text-cinema-text-dim focus:outline-none focus:border-cinema-gold/40 w-40"
          />
        </div>
      </div>

      {/* Stats bar */}
      {stats && (
        <div className="flex items-center gap-6 px-6 py-2 text-[11px] text-cinema-text-dim border-b border-cinema-border/50 bg-cinema-bg/50">
          <span>
            <span className="text-cinema-gold/60 mr-1">📚</span>
            {stats.total_books} books
          </span>
          <span>
            <span className="text-cinema-gold/60 mr-1">✍️</span>
            {stats.total_authors} authors
          </span>
          <span>
            <span className="text-cinema-gold/60 mr-1">📖</span>
            {books.filter((b) => b.reading_progress > 0 && !b.finished).length} reading
          </span>
          <span>
            <span className="text-cinema-gold/60 mr-1">✅</span>
            {books.filter((b) => b.finished).length} finished
          </span>
        </div>
      )}

      {/* Grid */}
      <div className="flex-1 overflow-y-auto p-6">
        {loading ? (
          <div className="flex items-center justify-center h-full">
            <div className="animate-spin w-8 h-8 border-2 border-cinema-gold/30 border-t-cinema-gold rounded-full" />
          </div>
        ) : filteredBooks.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full gap-4 text-cinema-text-dim">
            <svg className="w-16 h-16 opacity-30" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
            </svg>
            <p className="text-sm">
              {subView === 'all'
                ? 'No books found. Scan a folder on the server to add books.'
                : subView === 'reading'
                ? 'No books in progress.'
                : 'No finished books yet.'}
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-[repeat(auto-fill,minmax(140px,1fr))] gap-5">
            {filteredBooks.map((book) => (
              <BookCard
                key={book.id}
                book={book}
                onSelect={() => setSelectedBook(book)}
              />
            ))}
          </div>
        )}
      </div>

      {/* Detail sheet */}
      <AnimatePresence>
        {selectedBook && (
          <BookDetailSheet
            book={selectedBook}
            onClose={() => setSelectedBook(null)}
          />
        )}
      </AnimatePresence>
    </div>
  );
}
