import React, { useEffect, useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

interface SplashScreenProps {
  onComplete: () => void;
}

const TITLE = 'CINEMATE';

function FilmReelIcon() {
  return (
    <svg width="72" height="72" viewBox="0 0 72 72" fill="none" xmlns="http://www.w3.org/2000/svg">
      <circle cx="36" cy="36" r="30" stroke="url(#reelGrad)" strokeWidth="2" opacity="0.8" />
      <circle cx="36" cy="36" r="22" stroke="url(#reelGrad)" strokeWidth="1.5" opacity="0.4" />
      <circle cx="36" cy="36" r="7" fill="url(#reelGrad)" opacity="0.9" />
      {[0, 45, 90, 135, 180, 225, 270, 315].map((angle) => {
        const rad = (angle * Math.PI) / 180;
        const x = 36 + 26 * Math.cos(rad);
        const y = 36 + 26 * Math.sin(rad);
        return <circle key={angle} cx={x} cy={y} r="3.5" fill="#d4a017" opacity="0.6" />;
      })}
      <defs>
        <linearGradient id="reelGrad" x1="0" y1="0" x2="72" y2="72">
          <stop offset="0%" stopColor="#ecbf3b" />
          <stop offset="50%" stopColor="#d4a017" />
          <stop offset="100%" stopColor="#b8860b" />
        </linearGradient>
      </defs>
    </svg>
  );
}

function Particles() {
  const particles = useMemo(
    () =>
      Array.from({ length: 40 }, (_, i) => ({
        id: i,
        x: Math.random() * 100,
        y: 50 + Math.random() * 50,
        size: Math.random() * 3 + 1,
        duration: Math.random() * 5 + 4,
        delay: Math.random() * 3,
        tx: (Math.random() - 0.5) * 150,
        ty: -(Math.random() * 400 + 150),
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
            background: `radial-gradient(circle, rgba(212, 160, 23, 0.9) 0%, rgba(236, 191, 59, 0.4) 100%)`,
          }}
          animate={{
            y: [0, p.ty],
            x: [0, p.tx],
            opacity: [0, 0.7, 0.7, 0],
            scale: [0.3, 1, 0.8, 0.2],
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

export default function SplashScreen({ onComplete }: SplashScreenProps) {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => {
      setProgress((prev) => {
        if (prev >= 100) {
          clearInterval(interval);
          return 100;
        }
        // Ease the progress — faster start, slower finish
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
      className="fixed inset-0 bg-cinema-bg flex flex-col items-center justify-center z-50"
      exit={{ opacity: 0, scale: 1.02 }}
      transition={{ duration: 0.8, ease: [0.4, 0, 0.2, 1] }}
    >
      <Particles />

      {/* Projector beam effect */}
      <div
        className="absolute top-0 left-1/2 -translate-x-1/2 w-[400px] h-[600px] projector-beam"
        style={{
          background: 'radial-gradient(ellipse at top, rgba(212,160,23,0.12) 0%, rgba(212,160,23,0.04) 40%, transparent 70%)',
          clipPath: 'polygon(42% 0%, 58% 0%, 82% 100%, 18% 100%)',
        }}
      />

      {/* Secondary ambient glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] rounded-full pointer-events-none"
        style={{
          background: 'radial-gradient(circle, rgba(212,160,23,0.06) 0%, transparent 70%)',
        }}
      />

      {/* Film reel icon */}
      <motion.div
        initial={{ opacity: 0, scale: 0.3, rotate: -270 }}
        animate={{ opacity: 1, scale: 1, rotate: 0 }}
        transition={{ duration: 1, ease: [0.34, 1.56, 0.64, 1] }}
        className="mb-8"
      >
        <motion.div
          animate={{ rotate: 360 }}
          transition={{ duration: 10, repeat: Infinity, ease: 'linear' }}
          className="drop-shadow-[0_0_20px_rgba(212,160,23,0.3)]"
        >
          <FilmReelIcon />
        </motion.div>
      </motion.div>

      {/* CINEMATE title — letter-by-letter cascade */}
      <div className="flex gap-[3px] mb-5">
        {TITLE.split('').map((letter, i) => (
          <motion.span
            key={i}
            className="text-5xl font-black tracking-wider text-gold-gradient"
            initial={{ opacity: 0, y: 40, rotateX: -90, scale: 0.8 }}
            animate={{ opacity: 1, y: 0, rotateX: 0, scale: 1 }}
            transition={{
              duration: 0.5,
              delay: 0.4 + i * 0.07,
              ease: [0.34, 1.56, 0.64, 1],
            }}
            style={{
              textShadow: '0 0 40px rgba(212, 160, 23, 0.4), 0 0 80px rgba(212, 160, 23, 0.15)',
              filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.5))',
            }}
          >
            {letter}
          </motion.span>
        ))}
      </div>

      {/* Tagline */}
      <motion.p
        className="text-cinema-text-secondary text-lg font-light tracking-[0.25em] mb-14"
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 0.8, y: 0 }}
        transition={{ delay: 1.3, duration: 0.8, ease: 'easeOut' }}
      >
        Your Private Cinema
      </motion.p>

      {/* Progress bar */}
      <motion.div
        className="w-72 h-[3px] bg-cinema-border/50 rounded-full overflow-hidden"
        initial={{ opacity: 0, scaleX: 0.6 }}
        animate={{ opacity: 1, scaleX: 1 }}
        transition={{ delay: 1.6, duration: 0.5, ease: 'easeOut' }}
      >
        <motion.div
          className="h-full progress-bar-gold rounded-full"
          style={{ width: `${progress}%` }}
          transition={{ ease: 'linear', duration: 0.04 }}
        />
      </motion.div>

      {/* Loading text */}
      <motion.p
        className="text-cinema-text-dim text-[10px] mt-5 tracking-[0.3em] font-medium"
        initial={{ opacity: 0 }}
        animate={{ opacity: 0.6 }}
        transition={{ delay: 2 }}
      >
        LOADING
      </motion.p>
    </motion.div>
  );
}
