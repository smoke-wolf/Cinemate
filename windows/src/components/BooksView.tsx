import React, { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { api } from '../api/client';
import { useAccounts } from '../hooks/useAccounts';
import type { BookItem } from '../api/types';
import BookDetailView from './BookDetailView';
import BookReaderView from './BookReaderView';

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

function formatReadingTime(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (hours > 0) return `${hours}h ${minutes}m`;
  if (minutes > 0) return `${minutes}m`;
  return '0m';
}

// ---------------------------------------------------------------------------
// BookCard
// ---------------------------------------------------------------------------

function BookCard({
  book,
  onSelect,
  onRead,
  onToggleFavorite,
  onMarkFinished,
}: {
  book: BookItem;
  onSelect: () => void;
  onRead: () => void;
  onToggleFavorite: () => void;
  onMarkFinished: () => void;
}) {
  const [hovered, setHovered] = useState(false);
  const [imgError, setImgError] = useState(false);
  const coverUrl = api.bookCoverUrl(book.id);
  const fmtColor = FORMAT_COLORS[book.format] || 'bg-gray-500';

  return (
    <motion.div
      className="group cursor-pointer"
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      whileHover={{ scale: 1.04 }}
      transition={{ duration: 0.15 }}
    >
      <div className="relative aspect-[0.7] rounded-lg overflow-hidden shadow-lg">
        {/* Cover */}
        {!imgError ? (
          <img
            src={coverUrl}
            alt={book.title}
            className="w-full h-full object-cover"
            onError={() => setImgError(true)}
          />
        ) : (
          <div className={`w-full h-full flex flex-col items-center justify-center gap-2 bg-gradient-to-br from-white/5 to-cinema-surface`}>
            <svg className="w-10 h-10 text-white/20" fill="currentColor" viewBox="0 0 24 24">
              <path d="M6 2a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8l-6-6H6zm7 1.5L18.5 9H13V3.5z" />
            </svg>
            <span className="text-white/40 text-xs text-center px-2 line-clamp-2">{book.title}</span>
          </div>
        )}

        {/* Spine shadows */}
        <div className="absolute top-0 right-0 bottom-0 w-1.5 bg-gradient-to-l from-black/15 to-transparent pointer-events-none" />
        <div className="absolute top-0 left-0 bottom-0 w-0.5 bg-gradient-to-r from-black/10 to-transparent pointer-events-none" />

        {/* Format badge */}
        <div className="absolute top-2 right-2 flex items-center gap-1">
          <span className={`${fmtColor}/90 text-white text-[9px] font-bold px-1.5 py-0.5 rounded`}>
            {book.format}
          </span>
          {book.finished && (
            <span className="bg-green-500/90 text-white text-[10px] rounded-full w-4 h-4 flex items-center justify-center">
              <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
              </svg>
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
              className="absolute inset-0 bg-black/55 flex flex-col items-center justify-center gap-3"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.15 }}
            >
              <button
                onClick={(e) => { e.stopPropagation(); onRead(); }}
                className="bg-cinema-gold text-black text-xs font-semibold px-4 py-1.5 rounded-md
                           hover:bg-cinema-gold-hover transition-colors"
              >
                {book.reading_progress > 0 && !book.finished ? 'Resume' : 'Read'}
              </button>
              <div className="flex items-center gap-3">
                <button
                  onClick={(e) => { e.stopPropagation(); onToggleFavorite(); }}
                  className="text-white hover:text-red-400 transition-colors"
                  title={book.favorite ? 'Remove favorite' : 'Add favorite'}
                >
                  <svg className="w-4 h-4" fill={book.favorite ? 'currentColor' : 'none'} viewBox="0 0 24 24"
                       stroke="currentColor" strokeWidth={book.favorite ? 0 : 2}
                       style={{ color: book.favorite ? '#f87171' : undefined }}>
                    <path strokeLinecap="round" strokeLinejoin="round"
                          d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                  </svg>
                </button>
                <button
                  onClick={(e) => { e.stopPropagation(); onMarkFinished(); }}
                  className="transition-colors"
                  title={book.finished ? 'Mark unfinished' : 'Mark finished'}
                  style={{ color: book.finished ? '#4ade80' : 'white' }}
                >
                  <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                </button>
                {book.page_count > 0 && (
                  <span className="text-white/50 text-[10px]">{book.page_count}p</span>
                )}
              </div>
              <button
                onClick={(e) => { e.stopPropagation(); onSelect(); }}
                className="text-white/60 text-[10px] underline underline-offset-2 hover:text-white transition-colors"
              >
                View Details
              </button>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Title + author below */}
      <div className="mt-2 px-0.5" onClick={onSelect}>
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

// ---------------------------------------------------------------------------
// AuthorRow
// ---------------------------------------------------------------------------

function AuthorRow({
  author,
  bookCount,
  onClick,
}: {
  author: string;
  bookCount: number;
  onClick: () => void;
}) {
  const [hovered, setHovered] = useState(false);
  const initial = author.charAt(0).toUpperCase();

  return (
    <button
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      className={`w-full flex items-center gap-3.5 px-6 py-2.5 text-left transition-colors ${
        hovered ? 'bg-white/[0.04]' : ''
      }`}
    >
      {/* Avatar */}
      <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0
                      bg-gradient-to-br from-orange-500/50 to-yellow-500/30">
        <span className="text-white text-sm font-bold">{initial}</span>
      </div>

      <div className="flex-1 min-w-0">
        <p className="text-white text-sm font-medium truncate">{author}</p>
        <p className="text-cinema-text-dim text-xs">
          {bookCount} {bookCount === 1 ? 'book' : 'books'}
        </p>
      </div>

      <svg className="w-3.5 h-3.5 text-cinema-text-dim/40 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
      </svg>
    </button>
  );
}

// ---------------------------------------------------------------------------
// Currently Reading Row
// ---------------------------------------------------------------------------

function CurrentlyReadingRow({
  books,
  onSelect,
  onRead,
}: {
  books: BookItem[];
  onSelect: (book: BookItem) => void;
  onRead: (book: BookItem) => void;
}) {
  if (books.length === 0) return null;

  return (
    <div className="px-6 pb-4">
      <h3 className="text-white text-sm font-semibold mb-3 flex items-center gap-2">
        <svg className="w-4 h-4 text-cinema-gold/70" fill="currentColor" viewBox="0 0 24 24">
          <path d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
        </svg>
        Continue Reading
      </h3>
      <div className="flex gap-4 overflow-x-auto pb-2 -mx-1 px-1">
        {books.map((book) => {
          const coverUrl = api.bookCoverUrl(book.id);
          const progressPct = Math.round(book.reading_progress * 100);
          return (
            <motion.div
              key={book.id}
              className="flex-shrink-0 w-[280px] flex gap-3 p-3 rounded-lg bg-white/[0.04] border border-cinema-border/30
                         cursor-pointer hover:bg-white/[0.06] transition-colors"
              onClick={() => onSelect(book)}
              whileHover={{ scale: 1.01 }}
            >
              <img
                src={coverUrl}
                alt={book.title}
                className="w-14 h-20 object-cover rounded flex-shrink-0"
                onError={(e) => {
                  (e.target as HTMLImageElement).style.display = 'none';
                }}
              />
              <div className="flex-1 min-w-0 flex flex-col justify-between">
                <div>
                  <p className="text-white text-xs font-medium line-clamp-2 leading-tight">{book.title}</p>
                  {book.author && (
                    <p className="text-cinema-text-dim text-[10px] mt-0.5 truncate">{book.author}</p>
                  )}
                </div>
                <div>
                  <div className="w-full h-1 bg-white/10 rounded-full overflow-hidden mt-1.5">
                    <div
                      className="h-full bg-cinema-gold rounded-full"
                      style={{ width: `${progressPct}%` }}
                    />
                  </div>
                  <div className="flex items-center justify-between mt-1">
                    <span className="text-cinema-text-dim text-[10px]">{progressPct}%</span>
                    <button
                      onClick={(e) => { e.stopPropagation(); onRead(book); }}
                      className="text-cinema-gold text-[10px] font-semibold hover:text-cinema-gold-hover transition-colors"
                    >
                      Resume
                    </button>
                  </div>
                </div>
              </div>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// BooksView (main)
// ---------------------------------------------------------------------------

export default function BooksView() {
  const { currentAccount } = useAccounts();
  const [books, setBooks] = useState<BookItem[]>([]);
  const [subView, setSubView] = useState<BookSubView>('all');
  const [sort, setSort] = useState<BookSort>('date_added');
  const [search, setSearch] = useState('');
  const [formatFilter, setFormatFilter] = useState<string | null>(null);
  const [selectedBook, setSelectedBook] = useState<BookItem | null>(null);
  const [readingBook, setReadingBook] = useState<BookItem | null>(null);
  const [loading, setLoading] = useState(true);
  const [authors, setAuthors] = useState<{ author: string; book_count: number }[]>([]);
  const [currentlyReading, setCurrentlyReading] = useState<BookItem[]>([]);
  const [stats, setStats] = useState<{
    total_books: number;
    total_authors: number;
    total_pages: number;
    format_breakdown: { format: string; count: number }[];
  } | null>(null);
  const [accountStats, setAccountStats] = useState<{
    books_finished: number;
    books_in_progress: number;
    total_reading_time_seconds: number;
    pages_read: number;
  } | null>(null);

  // Load books
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

  // Load stats
  useEffect(() => {
    api.getBookStats().then(setStats).catch(() => {});
  }, []);

  // Load account-specific data
  useEffect(() => {
    if (!currentAccount) return;
    api.getAccountBookStats(currentAccount.id).then(setAccountStats).catch(() => {});
    api.getCurrentlyReading(currentAccount.id).then(setCurrentlyReading).catch(() => setCurrentlyReading([]));
  }, [currentAccount]);

  // Load authors when on authors tab
  useEffect(() => {
    if (subView === 'authors') {
      api.getBookAuthors().then(setAuthors).catch(() => setAuthors([]));
    }
  }, [subView]);

  const filteredBooks = books.filter((b) => {
    if (subView === 'reading') return b.reading_progress > 0 && !b.finished;
    if (subView === 'finished') return b.finished;
    return true;
  });

  const handleRefresh = () => {
    loadBooks();
    if (currentAccount) {
      api.getAccountBookStats(currentAccount.id).then(setAccountStats).catch(() => {});
      api.getCurrentlyReading(currentAccount.id).then(setCurrentlyReading).catch(() => setCurrentlyReading([]));
    }
    api.getBookStats().then(setStats).catch(() => {});
  };

  const handleToggleFavorite = async (book: BookItem) => {
    if (!currentAccount) return;
    try {
      await api.toggleBookFavorite(currentAccount.id, book.id);
      handleRefresh();
    } catch {}
  };

  const handleMarkFinished = async (book: BookItem) => {
    if (!currentAccount) return;
    try {
      if (book.finished) {
        await api.updateBookProgress(currentAccount.id, book.id, Math.min(book.reading_progress, 0.9));
      } else {
        await api.markBookFinished(currentAccount.id, book.id);
      }
      handleRefresh();
    } catch {}
  };

  const handleAuthorClick = (authorName: string) => {
    setSubView('all');
    setSearch(authorName);
  };

  const SUB_VIEWS: { key: BookSubView; label: string }[] = [
    { key: 'all', label: 'All Books' },
    { key: 'reading', label: 'Currently Reading' },
    { key: 'finished', label: 'Finished' },
    { key: 'authors', label: 'Authors' },
  ];

  const FORMATS = ['EPUB', 'PDF', 'MOBI', 'AZW3', 'CBZ', 'CBR', 'FB2', 'DJVU'];

  const totalBooksCount = stats?.total_books ?? books.length;
  const readingCount = accountStats?.books_in_progress ?? books.filter((b) => b.reading_progress > 0 && !b.finished).length;
  const finishedCount = accountStats?.books_finished ?? books.filter((b) => b.finished).length;
  const readingTime = accountStats?.total_reading_time_seconds ?? 0;
  const pagesRead = accountStats?.pages_read ?? 0;

  // If reader is open, render it full-screen
  if (readingBook) {
    return (
      <BookReaderView
        book={readingBook}
        onClose={() => {
          setReadingBook(null);
          handleRefresh();
        }}
      />
    );
  }

  return (
    <div className="h-full flex flex-col">
      {/* Sub-nav */}
      <div className="flex items-center gap-1 px-6 py-2.5 border-b border-cinema-border bg-cinema-surface/50">
        {SUB_VIEWS.map((sv) => (
          <button
            key={sv.key}
            onClick={() => setSubView(sv.key)}
            className={`px-3.5 py-1.5 rounded-md text-xs font-medium transition-colors ${
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
          {search && (
            <button
              onClick={() => setSearch('')}
              className="absolute right-2 top-1/2 -translate-y-1/2 text-cinema-text-dim hover:text-white transition-colors"
            >
              <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
              </svg>
            </button>
          )}
        </div>
      </div>

      {/* Stats bar */}
      <div className="flex items-center gap-4 px-6 py-2 text-[11px] text-cinema-text-dim border-b border-cinema-border/50 bg-cinema-bg/50">
        <StatItem icon="book-closed" value={totalBooksCount} label="books" />
        <div className="w-px h-3.5 bg-cinema-border/50" />
        <StatItem icon="book" value={readingCount} label="reading" />
        <div className="w-px h-3.5 bg-cinema-border/50" />
        <StatItem icon="check" value={finishedCount} label="finished" />
        <div className="w-px h-3.5 bg-cinema-border/50" />
        <StatItem icon="clock" value={formatReadingTime(readingTime)} label="reading time" />
        {pagesRead > 0 && (
          <>
            <div className="w-px h-3.5 bg-cinema-border/50" />
            <StatItem icon="pages" value={pagesRead.toLocaleString()} label="pages read" />
          </>
        )}
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto">
        {subView === 'authors' ? (
          /* Authors list */
          loading ? (
            <div className="flex items-center justify-center h-full">
              <div className="animate-spin w-8 h-8 border-2 border-cinema-gold/30 border-t-cinema-gold rounded-full" />
            </div>
          ) : authors.length === 0 ? (
            <EmptyState message="No authors found" />
          ) : (
            <div className="py-3">
              {authors.map((a) => (
                <AuthorRow
                  key={a.author}
                  author={a.author}
                  bookCount={a.book_count}
                  onClick={() => handleAuthorClick(a.author)}
                />
              ))}
            </div>
          )
        ) : (
          /* Book grid */
          <>
            {/* Currently reading row (only on "all" tab) */}
            {subView === 'all' && currentlyReading.length > 0 && !search && (
              <div className="pt-4">
                <CurrentlyReadingRow
                  books={currentlyReading}
                  onSelect={(b) => setSelectedBook(b)}
                  onRead={(b) => setReadingBook(b)}
                />
              </div>
            )}

            <div className="p-6">
              {loading ? (
                <div className="flex items-center justify-center h-64">
                  <div className="animate-spin w-8 h-8 border-2 border-cinema-gold/30 border-t-cinema-gold rounded-full" />
                </div>
              ) : filteredBooks.length === 0 ? (
                <EmptyState
                  message={
                    subView === 'all'
                      ? 'No books found. Scan a folder on the server to add books.'
                      : subView === 'reading'
                        ? 'No books in progress.'
                        : 'No finished books yet.'
                  }
                />
              ) : (
                <div className="grid grid-cols-[repeat(auto-fill,minmax(140px,1fr))] gap-5">
                  {filteredBooks.map((book) => (
                    <BookCard
                      key={book.id}
                      book={book}
                      onSelect={() => setSelectedBook(book)}
                      onRead={() => setReadingBook(book)}
                      onToggleFavorite={() => handleToggleFavorite(book)}
                      onMarkFinished={() => handleMarkFinished(book)}
                    />
                  ))}
                </div>
              )}
            </div>
          </>
        )}
      </div>

      {/* Detail overlay */}
      <AnimatePresence>
        {selectedBook && (
          <BookDetailView
            book={selectedBook}
            onClose={() => setSelectedBook(null)}
            onRead={() => {
              const book = selectedBook;
              setSelectedBook(null);
              setReadingBook(book);
            }}
            onBookUpdated={handleRefresh}
          />
        )}
      </AnimatePresence>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function StatItem({ icon, value, label }: { icon: string; value: string | number; label: string }) {
  const iconSvg = {
    'book-closed': (
      <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
        <path d="M6 2a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8l-6-6H6zm7 1.5L18.5 9H13V3.5z" />
      </svg>
    ),
    book: (
      <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
        <path d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
      </svg>
    ),
    check: (
      <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
      </svg>
    ),
    clock: (
      <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clipRule="evenodd" />
      </svg>
    ),
    pages: (
      <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
        <path d="M7 3a2 2 0 00-2 2v14a2 2 0 002 2h10a2 2 0 002-2V9l-6-6H7zm6 1.5L18.5 10H13V4.5z" />
      </svg>
    ),
  }[icon];

  return (
    <span className="flex items-center gap-1.5">
      <span className="text-cinema-gold/60">{iconSvg}</span>
      <span>{value} {label}</span>
    </span>
  );
}

function EmptyState({ message }: { message: string }) {
  return (
    <div className="flex flex-col items-center justify-center h-64 gap-4 text-cinema-text-dim">
      <svg className="w-16 h-16 opacity-30" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1}
              d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
      </svg>
      <p className="text-sm">{message}</p>
    </div>
  );
}
