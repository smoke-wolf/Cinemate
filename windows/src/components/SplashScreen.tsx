import React, { useEffect, useState, useMemo } from 'react';
import { motion } from 'framer-motion';

interface SplashScreenProps {
  onComplete: () => void;
}

const TITLE = 'CINEMATE';
const ACCENT_GOLD = 'rgb(212, 160, 23)';
const WARM_AMBER = 'rgb(236, 191, 59)';
const DEEP_GOLD = 'rgb(184, 134, 11)';
const RICH_BLACK = 'rgb(10, 10, 15)';

/* ─── Film Reel Icon — matching macOS film.circle with gold gradient ─── */

function FilmReelIcon() {
  return (
    <svg width="52" height="52" viewBox="0 0 52 52" fill="none" xmlns="http://www.w3.org/2000/svg">
      <circle cx="26" cy="26" r="22" stroke="url(#reelGrad)" strokeWidth="1.5" opacity="0.8" />
      <circle cx="26" cy="26" r="16" stroke="url(#reelGrad)" strokeWidth="1" opacity="0.35" />
      <circle cx="26" cy="26" r="5" fill="url(#reelGrad)" opacity="0.9" />
      {[0, 45, 90, 135, 180, 225, 270, 315].map((angle) => {
        const rad = (angle * Math.PI) / 180;
        const x = 26 + 19 * Math.cos(rad);
        const y = 26 + 19 * Math.sin(rad);
        return <circle key={angle} cx={x} cy={y} r="2.5" fill={ACCENT_GOLD} opacity="0.6" />;
      })}
      <defs>
        <linearGradient id="reelGrad" x1="0" y1="0" x2="52" y2="52">
          <stop offset="0%" stopColor={WARM_AMBER} />
          <stop offset="50%" stopColor={ACCENT_GOLD} />
          <stop offset="100%" stopColor={DEEP_GOLD} />
        </linearGradient>
      </defs>
    </svg>
  );
}

/* ─── Dust Particles — matching macOS DustParticlesView ─── */

function DustParticles() {
  const particles = useMemo(
    () =>
      Array.from({ length: 40 }, (_, i) => ({
        id: i,
        x: 30 + Math.random() * 40, // concentrated in center beam
        y: 20 + Math.random() * 60,
        size: Math.random() * 2.5 + 0.5,
        duration: Math.random() * 5 + 4,
        delay: Math.random() * 3,
        ty: -(Math.random() * 300 + 100),
      })),
    []
  );

  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none">
      {particles.map((p) => (
        <motion.div
          key={p.id}
          className="absolute rounded-full"
          style={{
            left: `${p.x}%`,
            top: `${p.y}%`,
            width: p.size,
            height: p.size,
            background: `radial-gradient(circle, ${WARM_AMBER} 0%, rgba(212,160,23,0.3) 100%)`,
          }}
          animate={{
            y: [0, p.ty],
            opacity: [0, 0.5, 0.5, 0],
            scale: [0.3, 1, 0.7, 0.1],
          }}
          transition={{
            duration: p.duration,
            delay: p.delay,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
        />
      ))}
    </div>
  );
}

/* ─── Film Strip Edge — matching macOS FilmStripEdge ─── */

function FilmStripEdge() {
  return (
    <div className="flex h-5 opacity-[0.08]">
      {Array.from({ length: 40 }, (_, i) => (
        <div key={i} className="flex items-center shrink-0">
          <div className="w-4 h-3 mx-1.5 rounded-sm bg-white/15" />
          <div className="w-px h-5 bg-white/5" />
        </div>
      ))}
    </div>
  );
}

/* ─── Cinematic Divider — matching macOS CinematicDivider ─── */

function CinematicDivider() {
  return (
    <div className="flex items-center gap-2">
      <div
        className="w-[60px] h-px"
        style={{ background: `linear-gradient(to right, transparent, rgba(212,160,23,0.4))` }}
      />
      <svg className="w-1.5 h-1.5 text-amber-400/60" fill="currentColor" viewBox="0 0 24 24">
        <path d="M12 2l2.4 7.4H22l-6 4.6 2.3 7L12 16.4 5.7 21l2.3-7L2 9.4h7.6z" />
      </svg>
      <div
        className="w-[60px] h-px"
        style={{ background: `linear-gradient(to right, rgba(212,160,23,0.4), transparent)` }}
      />
    </div>
  );
}

/* ─── Main SplashScreen — matching macOS SplashScreenView ─── */

export default function SplashScreen({ onComplete }: SplashScreenProps) {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => {
      setProgress((prev) => {
        if (prev >= 100) {
          clearInterval(interval);
          return 100;
        }
        const remaining = 100 - prev;
        const step = Math.max(0.5, remaining * 0.06);
        return Math.min(100, prev + step);
      });
    }, 40);

    const timer = setTimeout(() => {
      onComplete();
    }, 3200);

    return () => {
      clearInterval(interval);
      clearTimeout(timer);
    };
  }, [onComplete]);

  return (
    <motion.div
      className="fixed inset-0 flex flex-col items-center justify-center z-50 overflow-hidden"
      style={{ backgroundColor: RICH_BLACK }}
      exit={{ opacity: 0, scale: 1.02 }}
      transition={{ duration: 0.8, ease: [0.4, 0, 0.2, 1] }}
    >
      {/* Layer 1: Radial vignette background */}
      <motion.div
        className="absolute inset-0 pointer-events-none"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.8, delay: 0.2 }}
        style={{
          background: `radial-gradient(ellipse at center, rgba(25, 20, 10, 0.6) 0%, ${RICH_BLACK} 70%)`,
        }}
      />

      {/* Layer 2: Film strip borders */}
      <motion.div
        className="absolute top-0 left-0 right-0 overflow-hidden"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.2, duration: 0.8 }}
      >
        <motion.div
          animate={{ x: [0, -200] }}
          transition={{ duration: 15, repeat: Infinity, ease: 'linear' }}
        >
          <FilmStripEdge />
        </motion.div>
      </motion.div>
      <motion.div
        className="absolute bottom-0 left-0 right-0 overflow-hidden"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.2, duration: 0.8 }}
      >
        <motion.div
          animate={{ x: [-200, 0] }}
          transition={{ duration: 15, repeat: Infinity, ease: 'linear' }}
        >
          <FilmStripEdge />
        </motion.div>
      </motion.div>

      {/* Layer 3: Projector beam cone */}
      <motion.div
        className="absolute top-0 left-1/2 -translate-x-1/2 pointer-events-none"
        initial={{ opacity: 0, scaleY: 0.3 }}
        animate={{ opacity: 1, scaleY: 1 }}
        transition={{ duration: 0.8, delay: 0.2, ease: 'easeOut' }}
        style={{
          width: '70%',
          height: '80%',
          transformOrigin: 'top center',
          background: `radial-gradient(ellipse at top center, rgba(212,160,23,0.08) 0%, rgba(212,160,23,0.02) 50%, transparent 70%)`,
        }}
      />

      {/* Layer 4: Secondary center hotspot */}
      <div
        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[400px] rounded-full pointer-events-none"
        style={{
          background: `radial-gradient(circle, rgba(255,255,255,0.03) 0%, rgba(212,160,23,0.015) 40%, transparent 70%)`,
        }}
      />

      {/* Layer 5: Dust particles */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 0.6 }}
        transition={{ delay: 0.3, duration: 1 }}
      >
        <DustParticles />
      </motion.div>

      {/* Layer 6: Main content */}
      <div className="relative z-10 flex flex-col items-center">
        {/* Film reel icon — rotating continuously */}
        <motion.div
          initial={{ opacity: 0, scale: 0.6 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.7, delay: 0.6, type: 'spring', damping: 0.8 }}
          className="mb-6"
        >
          <motion.div
            animate={{ rotate: 360 }}
            transition={{ duration: 20, repeat: Infinity, ease: 'linear' }}
            style={{
              filter: `drop-shadow(0 0 20px rgba(212,160,23,0.3))`,
            }}
          >
            <FilmReelIcon />
          </motion.div>
        </motion.div>

        {/* CINEMATE — letter-by-letter kinetic cascade */}
        <div className="flex gap-[3px] mb-4">
          {TITLE.split('').map((letter, i) => (
            <motion.span
              key={i}
              className="text-[56px] font-bold tracking-[2px]"
              initial={{ opacity: 0, y: 40 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{
                duration: 0.5,
                delay: 0.8 + i * 0.06,
                type: 'spring',
                damping: 0.7,
              }}
              style={{
                background: `linear-gradient(180deg, ${WARM_AMBER}, ${ACCENT_GOLD}, ${DEEP_GOLD})`,
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                backgroundClip: 'text',
                filter: 'drop-shadow(0 0 8px rgba(212,160,23,0.6)) drop-shadow(0 0 24px rgba(212,160,23,0.2))',
              }}
            >
              {letter}
            </motion.span>
          ))}
        </div>

        {/* Cinematic divider */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1.5, duration: 0.6 }}
          className="mb-3"
        >
          <CinematicDivider />
        </motion.div>

        {/* Tagline */}
        <motion.p
          className="text-[14px] font-medium tracking-[6px]"
          style={{ color: `rgba(212,160,23,0.7)` }}
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 1.5, duration: 0.6, ease: 'easeOut' }}
        >
          Your Private Cinema
        </motion.p>
      </div>

      {/* Loading progress bar — at bottom */}
      <div className="absolute bottom-16 flex flex-col items-center gap-3">
        <motion.div
          className="relative"
          initial={{ opacity: 0, scaleX: 0.6 }}
          animate={{ opacity: 1, scaleX: 1 }}
          transition={{ delay: 1.6, duration: 0.5, ease: 'easeOut' }}
        >
          <div className="w-[200px] h-[2px] rounded-sm bg-white/[0.06]">
            <motion.div
              className="h-full rounded-sm"
              style={{
                width: `${progress}%`,
                background: `linear-gradient(90deg, ${DEEP_GOLD}, ${ACCENT_GOLD}, ${WARM_AMBER})`,
                boxShadow: `0 0 6px rgba(212,160,23,0.5)`,
              }}
              transition={{ ease: 'linear', duration: 0.04 }}
            />
          </div>
        </motion.div>

        <motion.span
          className="text-[10px] font-normal tracking-[3px] text-white/30"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 2 }}
        >
          Loading
        </motion.span>
      </div>

      {/* Layer 7: Vignette overlay */}
      <motion.div
        className="absolute inset-0 pointer-events-none"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.2, duration: 0.8 }}
        style={{
          background: `radial-gradient(circle at center, transparent 25%, transparent 35%, rgba(10,10,15,0.5) 60%, rgba(10,10,15,0.9) 100%)`,
        }}
      />
    </motion.div>
  );
}
