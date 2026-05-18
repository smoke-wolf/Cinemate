import React, { useState, useEffect, useCallback, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { api } from '../api/client';
import { useAccounts } from '../hooks/useAccounts';
import type { BookItem } from '../api/types';

interface BookReaderViewProps {
  book: BookItem;
  onClose: () => void;
}

interface EpubChapter {
  index: number;
  title: string;
  is_front_matter?: boolean;
}

// ---------------------------------------------------------------------------
// Bookmark Dialog
// ---------------------------------------------------------------------------

function BookmarkDialog({
  currentPage,
  onSave,
  onCancel,
}: {
  currentPage: number;
  onSave: (page: number, note: string) => void;
  onCancel: () => void;
}) {
  const [note, setNote] = useState('');

  return (
    <motion.div
      className="fixed inset-0 z-[60] flex items-center justify-center bg-black/60 backdrop-blur-sm"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      onClick={onCancel}
    >
      <motion.div
        className="bg-cinema-card rounded-xl p-6 w-[320px] shadow-2xl border border-cinema-border"
        initial={{ scale: 0.9, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        exit={{ scale: 0.9, opacity: 0 }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center gap-2 mb-4">
          <svg className="w-4 h-4 text-cinema-gold" fill="currentColor" viewBox="0 0 24 24">
            <path d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" />
          </svg>
          <span className="text-white font-bold">Add Bookmark</span>
        </div>

        <div className="text-cinema-text-dim text-xs mb-3 px-2 py-1 bg-white/5 rounded inline-block">
          Page {currentPage}
        </div>

        <input
          type="text"
          placeholder="Note (optional)"
          value={note}
          onChange={(e) => setNote(e.target.value)}
          className="w-full bg-white/5 border border-cinema-border rounded-md px-3 py-2 text-sm text-white
                     placeholder:text-cinema-text-dim focus:outline-none focus:border-cinema-gold/40 mb-4"
          autoFocus
          onKeyDown={(e) => {
            if (e.key === 'Enter') onSave(currentPage, note);
          }}
        />

        <div className="flex gap-3 justify-end">
          <button
            onClick={onCancel}
            className="px-4 py-1.5 text-sm text-cinema-text-dim bg-white/5 rounded-md hover:bg-white/10 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={() => onSave(currentPage, note)}
            className="px-4 py-1.5 text-sm font-semibold text-black bg-cinema-gold rounded-md hover:bg-cinema-gold-hover transition-colors"
          >
            Save
          </button>
        </div>
      </motion.div>
    </motion.div>
  );
}

// ---------------------------------------------------------------------------
// PDF Reader
// ---------------------------------------------------------------------------

function PDFReader({ book, onClose }: { book: BookItem; onClose: () => void }) {
  const { currentAccount } = useAccounts();
  const [nightMode, setNightMode] = useState(true);
  const [showBookmarkDialog, setShowBookmarkDialog] = useState(false);
  const [currentPage, setCurrentPage] = useState(book.current_page || 1);
  const [totalPages, setTotalPages] = useState(book.page_count || 0);
  const [zoom, setZoom] = useState(100);
  const lastSaveRef = useRef(Date.now());
  const pdfUrl = api.bookFileUrl(book.id);

  const progressPercent = totalPages > 0 ? Math.min(Math.round((currentPage / totalPages) * 100), 100) : 0;

  const saveProgress = useCallback(() => {
    if (!currentAccount || totalPages === 0) return;
    const progress = Math.min(currentPage / totalPages, 1.0);
    api.updateBookProgress(currentAccount.id, book.id, progress, currentPage).catch(() => {});
  }, [currentAccount, book.id, currentPage, totalPages]);

  // Auto-save every 15 seconds on page change
  useEffect(() => {
    if (Date.now() - lastSaveRef.current > 15000) {
      saveProgress();
      lastSaveRef.current = Date.now();
    }
  }, [currentPage, saveProgress]);

  // Save on unmount
  useEffect(() => {
    return () => { saveProgress(); };
  }, [saveProgress]);

  // Keyboard navigation
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'ArrowLeft') {
        setCurrentPage((p) => Math.max(1, p - 1));
      } else if (e.key === 'ArrowRight') {
        setCurrentPage((p) => Math.min(totalPages || p + 1, p + 1));
      } else if (e.key === 'Escape') {
        saveProgress();
        onClose();
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [totalPages, saveProgress, onClose]);

  const handleBookmark = async (page: number, note: string) => {
    if (!currentAccount) return;
    try {
      await api.addBookBookmark(currentAccount.id, book.id, page, note || undefined);
    } catch {}
    setShowBookmarkDialog(false);
  };

  // For PDFs in Electron, we embed using object/embed or iframe with the PDF viewer
  // The URL with #page=N&zoom=Z allows navigation
  const pdfSrc = `${pdfUrl}#page=${currentPage}&zoom=${zoom}`;

  return (
    <motion.div
      className="fixed inset-0 z-50 flex flex-col"
      style={{ background: nightMode ? '#000' : '#1a1a1a' }}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
    >
      {/* Top bar */}
      <div className="flex items-center gap-3 px-4 py-2 bg-[#0d0d0d] border-b border-cinema-border/30 flex-shrink-0">
        {/* Back button */}
        <button
          onClick={() => { saveProgress(); onClose(); }}
          className="flex items-center gap-1.5 px-3 py-1.5 text-white text-xs bg-white/8 hover:bg-white/12 rounded-md transition-colors"
        >
          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
          <span className="font-medium truncate max-w-[200px]">{book.title}</span>
        </button>

        <div className="flex-1" />

        {/* Page navigation */}
        <div className="flex items-center gap-1.5">
          <button
            onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
            disabled={currentPage <= 1}
            className="w-7 h-7 flex items-center justify-center rounded bg-white/5 text-white/70
                       hover:bg-white/10 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
          >
            <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <span className="text-white/60 text-xs font-medium tabular-nums px-2 min-w-[100px] text-center">
            Page {currentPage} of {totalPages || '...'}
          </span>
          <button
            onClick={() => setCurrentPage((p) => Math.min(totalPages || p + 1, p + 1))}
            disabled={totalPages > 0 && currentPage >= totalPages}
            className="w-7 h-7 flex items-center justify-center rounded bg-white/5 text-white/70
                       hover:bg-white/10 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
          >
            <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>

        <div className="flex-1" />

        {/* Controls */}
        <div className="flex items-center gap-1.5">
          {/* Zoom */}
          <button
            onClick={() => setZoom((z) => Math.max(50, z - 25))}
            className="w-7 h-7 flex items-center justify-center rounded bg-white/5 text-white/70 hover:bg-white/10 transition-colors"
            title="Zoom out"
          >
            <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM13 10H7" />
            </svg>
          </button>
          <span className="text-white/50 text-[10px] tabular-nums w-9 text-center">{zoom}%</span>
          <button
            onClick={() => setZoom((z) => Math.min(300, z + 25))}
            className="w-7 h-7 flex items-center justify-center rounded bg-white/5 text-white/70 hover:bg-white/10 transition-colors"
            title="Zoom in"
          >
            <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v6m3-3H7" />
            </svg>
          </button>

          <div className="w-px h-4 bg-white/10 mx-1" />

          {/* Bookmark */}
          <button
            onClick={() => setShowBookmarkDialog(true)}
            className="w-7 h-7 flex items-center justify-center rounded bg-white/5 text-white/70 hover:bg-white/10 transition-colors"
            title="Add bookmark"
          >
            <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" />
            </svg>
          </button>

          {/* Night mode */}
          <button
            onClick={() => setNightMode((n) => !n)}
            className={`w-7 h-7 flex items-center justify-center rounded bg-white/5 transition-colors
              ${nightMode ? 'text-yellow-400 hover:bg-yellow-400/10' : 'text-white/70 hover:bg-white/10'}`}
            title={nightMode ? 'Light mode' : 'Dark mode'}
          >
            {nightMode ? (
              <svg className="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 2.25a.75.75 0 01.75.75v2.25a.75.75 0 01-1.5 0V3a.75.75 0 01.75-.75zM7.5 12a4.5 4.5 0 119 0 4.5 4.5 0 01-9 0z" />
                <path fillRule="evenodd" d="M6.697 5.757a.75.75 0 011.06-.06l1.591 1.432a.75.75 0 01-1.004 1.116L6.753 6.813a.75.75 0 01-.056-1.056zm10.606-.06a.75.75 0 01-.056 1.056l-1.591 1.432a.75.75 0 11-1.004-1.116l1.59-1.432a.75.75 0 011.061.06zM12 16.5a.75.75 0 01.75.75v2.25a.75.75 0 01-1.5 0v-2.25a.75.75 0 01.75-.75zM7.757 17.303a.75.75 0 011.056.056l1.432 1.591a.75.75 0 01-1.116 1.004l-1.432-1.59a.75.75 0 01.06-1.061zm9.545-.06a.75.75 0 01-.06 1.061l-1.432 1.59a.75.75 0 11-1.116-1.004l1.432-1.591a.75.75 0 011.056-.056zM2.25 12a.75.75 0 01.75-.75h2.25a.75.75 0 010 1.5H3a.75.75 0 01-.75-.75zm16.5 0a.75.75 0 01.75-.75h2.25a.75.75 0 010 1.5H19.5a.75.75 0 01-.75-.75z" clipRule="evenodd" />
              </svg>
            ) : (
              <svg className="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24">
                <path fillRule="evenodd" d="M9.528 1.718a.75.75 0 01.162.819A8.97 8.97 0 009 6a9 9 0 009 9 8.97 8.97 0 003.463-.69.75.75 0 01.981.98 10.503 10.503 0 01-9.694 6.46c-5.799 0-10.5-4.701-10.5-10.5 0-4.368 2.667-8.112 6.46-9.694a.75.75 0 01.818.162z" clipRule="evenodd" />
              </svg>
            )}
          </button>
        </div>
      </div>

      {/* Progress bar */}
      <div className="h-0.5 bg-white/5 flex-shrink-0">
        <motion.div
          className="h-full bg-cinema-gold/60"
          animate={{ width: `${progressPercent}%` }}
          transition={{ duration: 0.3 }}
        />
      </div>

      {/* PDF content */}
      <div className="flex-1 overflow-hidden" style={{ filter: nightMode ? 'invert(1) hue-rotate(180deg)' : 'none' }}>
        <embed
          key={`${pdfUrl}-${zoom}`}
          src={pdfSrc}
          type="application/pdf"
          className="w-full h-full"
          style={{ border: 'none' }}
        />
      </div>

      {/* Bottom bar: slider */}
      <div className="flex items-center gap-3 px-5 py-2 bg-[#0d0d0d] border-t border-cinema-border/30 flex-shrink-0">
        <span className="text-white/40 text-[10px] tabular-nums">1</span>
        {totalPages > 1 ? (
          <input
            type="range"
            min={1}
            max={totalPages}
            value={currentPage}
            onChange={(e) => setCurrentPage(Number(e.target.value))}
            className="flex-1 h-1 accent-cinema-gold cursor-pointer"
          />
        ) : (
          <div className="flex-1" />
        )}
        <span className="text-white/40 text-[10px] tabular-nums">{totalPages || '...'}</span>
        <span className="text-cinema-gold/60 text-[11px] font-medium tabular-nums w-10 text-right">
          {progressPercent}%
        </span>
      </div>

      <AnimatePresence>
        {showBookmarkDialog && (
          <BookmarkDialog
            currentPage={currentPage}
            onSave={handleBookmark}
            onCancel={() => setShowBookmarkDialog(false)}
          />
        )}
      </AnimatePresence>
    </motion.div>
  );
}

// ---------------------------------------------------------------------------
// EPUB Reader
// ---------------------------------------------------------------------------

function EPUBReader({ book, onClose }: { book: BookItem; onClose: () => void }) {
  const { currentAccount } = useAccounts();
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const [nightMode, setNightMode] = useState(true);
  const [fontSize, setFontSize] = useState(16);
  const [chapters, setChapters] = useState<EpubChapter[]>([]);
  const [currentChapter, setCurrentChapter] = useState(0);
  const [totalChapters, setTotalChapters] = useState(0);
  const [firstContentIndex, setFirstContentIndex] = useState(0);
  const [loading, setLoading] = useState(true);
  const [showToc, setShowToc] = useState(false);
  const [showBookmarkDialog, setShowBookmarkDialog] = useState(false);
  const lastSaveRef = useRef(Date.now());

  const progressPercent = totalChapters > 0 ? Math.min(Math.round(((currentChapter + 1) / totalChapters) * 100), 100) : 0;

  // Load TOC
  useEffect(() => {
    api.getEpubToc(book.id)
      .then((toc) => {
        setChapters(toc.chapters);
        setTotalChapters(toc.total);
        setFirstContentIndex(toc.first_content_index);
        // Start at saved position or first content chapter
        const startChapter = book.current_page > 0 ? book.current_page : toc.first_content_index;
        setCurrentChapter(startChapter);
      })
      .catch(() => {
        // If TOC fails, still allow reading
        setCurrentChapter(book.current_page > 0 ? book.current_page : 0);
      });
  }, [book.id, book.current_page]);

  // Load chapter content
  useEffect(() => {
    setLoading(true);
  }, [currentChapter]);

  const saveProgress = useCallback(() => {
    if (!currentAccount || totalChapters === 0) return;
    const progress = Math.min((currentChapter + 1) / totalChapters, 1.0);
    api.updateBookProgress(currentAccount.id, book.id, progress, currentChapter).catch(() => {});
  }, [currentAccount, book.id, currentChapter, totalChapters]);

  // Auto-save
  useEffect(() => {
    if (Date.now() - lastSaveRef.current > 15000) {
      saveProgress();
      lastSaveRef.current = Date.now();
    }
  }, [currentChapter, saveProgress]);

  // Save on unmount
  useEffect(() => {
    return () => { saveProgress(); };
  }, [saveProgress]);

  // Keyboard
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'ArrowLeft') {
        setCurrentChapter((c) => Math.max(0, c - 1));
      } else if (e.key === 'ArrowRight') {
        setCurrentChapter((c) => Math.min((totalChapters || c + 2) - 1, c + 1));
      } else if (e.key === 'Escape') {
        saveProgress();
        onClose();
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [totalChapters, saveProgress, onClose]);

  // Apply font size and night mode to iframe content
  useEffect(() => {
    const iframe = iframeRef.current;
    if (!iframe) return;

    const applyStyles = () => {
      try {
        const doc = iframe.contentDocument;
        if (!doc || !doc.body) return;
        doc.body.style.fontSize = `${fontSize}px`;
        doc.body.className = nightMode ? 'dark' : 'light';
      } catch {}
    };

    iframe.addEventListener('load', applyStyles);
    // Also apply immediately
    applyStyles();
    return () => iframe.removeEventListener('load', applyStyles);
  }, [fontSize, nightMode, currentChapter]);

  const handleBookmark = async (page: number, note: string) => {
    if (!currentAccount) return;
    try {
      await api.addBookBookmark(currentAccount.id, book.id, page, note || undefined);
    } catch {}
    setShowBookmarkDialog(false);
  };

  const chapterUrl = api.bookEpubHtmlUrl(book.id, currentChapter);
  const currentChapterTitle = chapters.find((c) => c.index === currentChapter)?.title || `Chapter ${currentChapter + 1}`;

  return (
    <motion.div
      className="fixed inset-0 z-50 flex flex-col"
      style={{ background: nightMode ? '#0a0a0f' : '#fafafa' }}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
    >
      {/* Top bar */}
      <div className={`flex items-center gap-3 px-4 py-2 border-b flex-shrink-0 ${
        nightMode ? 'bg-[#0d0d0d] border-cinema-border/30' : 'bg-white border-gray-200'
      }`}>
        {/* Back */}
        <button
          onClick={() => { saveProgress(); onClose(); }}
          className={`flex items-center gap-1.5 px-3 py-1.5 text-xs rounded-md transition-colors ${
            nightMode
              ? 'text-white bg-white/8 hover:bg-white/12'
              : 'text-gray-700 bg-gray-100 hover:bg-gray-200'
          }`}
        >
          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
          <span className="font-medium truncate max-w-[200px]">{book.title}</span>
        </button>

        <div className="flex-1" />

        {/* Chapter title */}
        <span className={`text-xs truncate max-w-[250px] ${nightMode ? 'text-white/50' : 'text-gray-500'}`}>
          {currentChapterTitle}
        </span>

        <div className="flex-1" />

        {/* Controls */}
        <div className="flex items-center gap-1.5">
          {/* TOC */}
          <button
            onClick={() => setShowToc(!showToc)}
            className={`w-7 h-7 flex items-center justify-center rounded transition-colors ${
              showToc
                ? 'bg-cinema-gold/20 text-cinema-gold'
                : nightMode ? 'bg-white/5 text-white/70 hover:bg-white/10' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
            title="Table of Contents"
          >
            <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>

          {/* Font size controls */}
          <button
            onClick={() => setFontSize((s) => Math.max(10, s - 2))}
            className={`w-7 h-7 flex items-center justify-center rounded transition-colors text-[10px] font-bold ${
              nightMode ? 'bg-white/5 text-white/70 hover:bg-white/10' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
            title="Decrease font size"
          >
            A-
          </button>
          <span className={`text-[10px] tabular-nums w-6 text-center ${nightMode ? 'text-white/40' : 'text-gray-400'}`}>
            {fontSize}
          </span>
          <button
            onClick={() => setFontSize((s) => Math.min(32, s + 2))}
            className={`w-7 h-7 flex items-center justify-center rounded transition-colors text-xs font-bold ${
              nightMode ? 'bg-white/5 text-white/70 hover:bg-white/10' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
            title="Increase font size"
          >
            A+
          </button>

          <div className={`w-px h-4 mx-1 ${nightMode ? 'bg-white/10' : 'bg-gray-200'}`} />

          {/* Bookmark */}
          <button
            onClick={() => setShowBookmarkDialog(true)}
            className={`w-7 h-7 flex items-center justify-center rounded transition-colors ${
              nightMode ? 'bg-white/5 text-white/70 hover:bg-white/10' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
            title="Add bookmark"
          >
            <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" />
            </svg>
          </button>

          {/* Night mode */}
          <button
            onClick={() => setNightMode((n) => !n)}
            className={`w-7 h-7 flex items-center justify-center rounded transition-colors ${
              nightMode
                ? 'bg-white/5 text-yellow-400 hover:bg-yellow-400/10'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
            title={nightMode ? 'Light mode' : 'Dark mode'}
          >
            {nightMode ? (
              <svg className="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 2.25a.75.75 0 01.75.75v2.25a.75.75 0 01-1.5 0V3a.75.75 0 01.75-.75zM7.5 12a4.5 4.5 0 119 0 4.5 4.5 0 01-9 0z" />
              </svg>
            ) : (
              <svg className="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24">
                <path fillRule="evenodd" d="M9.528 1.718a.75.75 0 01.162.819A8.97 8.97 0 009 6a9 9 0 009 9 8.97 8.97 0 003.463-.69.75.75 0 01.981.98 10.503 10.503 0 01-9.694 6.46c-5.799 0-10.5-4.701-10.5-10.5 0-4.368 2.667-8.112 6.46-9.694a.75.75 0 01.818.162z" clipRule="evenodd" />
              </svg>
            )}
          </button>
        </div>
      </div>

      {/* Progress bar */}
      <div className={`h-0.5 flex-shrink-0 ${nightMode ? 'bg-white/5' : 'bg-gray-200'}`}>
        <motion.div
          className="h-full bg-cinema-gold/60"
          animate={{ width: `${progressPercent}%` }}
          transition={{ duration: 0.3 }}
        />
      </div>

      {/* Content area */}
      <div className="flex-1 flex overflow-hidden relative">
        {/* TOC sidebar */}
        <AnimatePresence>
          {showToc && (
            <motion.div
              className={`w-72 flex-shrink-0 overflow-y-auto border-r ${
                nightMode ? 'bg-[#111] border-cinema-border/30' : 'bg-gray-50 border-gray-200'
              }`}
              initial={{ width: 0, opacity: 0 }}
              animate={{ width: 288, opacity: 1 }}
              exit={{ width: 0, opacity: 0 }}
              transition={{ duration: 0.2 }}
            >
              <div className="p-3">
                <h3 className={`text-xs font-semibold mb-2 ${nightMode ? 'text-white/60' : 'text-gray-500'}`}>
                  Contents
                </h3>
                <div className="space-y-0.5">
                  {chapters.map((ch) => (
                    <button
                      key={ch.index}
                      onClick={() => {
                        setCurrentChapter(ch.index);
                        setShowToc(false);
                      }}
                      className={`w-full text-left px-2.5 py-1.5 rounded text-xs transition-colors truncate ${
                        ch.index === currentChapter
                          ? 'bg-cinema-gold/20 text-cinema-gold font-medium'
                          : ch.is_front_matter
                            ? nightMode ? 'text-white/30 hover:bg-white/5' : 'text-gray-400 hover:bg-gray-100'
                            : nightMode ? 'text-white/70 hover:bg-white/5' : 'text-gray-700 hover:bg-gray-100'
                      }`}
                    >
                      {ch.title}
                    </button>
                  ))}
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* EPUB iframe */}
        <div className="flex-1 relative">
          {loading && (
            <div className="absolute inset-0 flex items-center justify-center z-10">
              <div className="animate-spin w-6 h-6 border-2 border-cinema-gold/30 border-t-cinema-gold rounded-full" />
            </div>
          )}
          <iframe
            ref={iframeRef}
            src={chapterUrl}
            sandbox="allow-same-origin"
            className="w-full h-full border-none"
            onLoad={() => {
              setLoading(false);
              try {
                const doc = iframeRef.current?.contentDocument;
                if (doc && doc.body) {
                  doc.body.style.fontSize = `${fontSize}px`;
                  doc.body.className = nightMode ? 'dark' : 'light';
                }
              } catch {}
            }}
          />
        </div>
      </div>

      {/* Bottom bar: chapter navigation */}
      <div className={`flex items-center gap-3 px-5 py-2 border-t flex-shrink-0 ${
        nightMode ? 'bg-[#0d0d0d] border-cinema-border/30' : 'bg-white border-gray-200'
      }`}>
        <button
          onClick={() => setCurrentChapter((c) => Math.max(0, c - 1))}
          disabled={currentChapter <= 0}
          className={`w-7 h-7 flex items-center justify-center rounded transition-colors
            disabled:opacity-30 disabled:cursor-not-allowed ${
            nightMode ? 'bg-white/5 text-white/70 hover:bg-white/10' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
          }`}
        >
          <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
        </button>

        {totalChapters > 1 ? (
          <input
            type="range"
            min={0}
            max={totalChapters - 1}
            value={currentChapter}
            onChange={(e) => setCurrentChapter(Number(e.target.value))}
            className="flex-1 h-1 accent-cinema-gold cursor-pointer"
          />
        ) : (
          <div className="flex-1" />
        )}

        <button
          onClick={() => setCurrentChapter((c) => Math.min((totalChapters || c + 2) - 1, c + 1))}
          disabled={totalChapters > 0 && currentChapter >= totalChapters - 1}
          className={`w-7 h-7 flex items-center justify-center rounded transition-colors
            disabled:opacity-30 disabled:cursor-not-allowed ${
            nightMode ? 'bg-white/5 text-white/70 hover:bg-white/10' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
          }`}
        >
          <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
          </svg>
        </button>

        <span className={`text-[11px] font-medium tabular-nums w-10 text-right ${
          nightMode ? 'text-cinema-gold/60' : 'text-cinema-gold'
        }`}>
          {progressPercent}%
        </span>
      </div>

      <AnimatePresence>
        {showBookmarkDialog && (
          <BookmarkDialog
            currentPage={currentChapter}
            onSave={handleBookmark}
            onCancel={() => setShowBookmarkDialog(false)}
          />
        )}
      </AnimatePresence>
    </motion.div>
  );
}

// ---------------------------------------------------------------------------
// Main BookReaderView — routes to PDF or EPUB reader
// ---------------------------------------------------------------------------

export default function BookReaderView({ book, onClose }: BookReaderViewProps) {
  if (book.format === 'PDF') {
    return <PDFReader book={book} onClose={onClose} />;
  }
  // EPUB and other formats use the HTML-rendered EPUB reader
  return <EPUBReader book={book} onClose={onClose} />;
}
