import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

// ─── Constants ───

const BAND_COUNT = 10;
const MIN_GAIN = -12;
const MAX_GAIN = 12;

const FREQUENCY_LABELS = ['32', '64', '125', '250', '500', '1K', '2K', '4K', '8K', '16K'];
const FREQUENCIES = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

interface EQPreset {
  name: string;
  gains: number[];
}

const EQ_PRESETS: EQPreset[] = [
  { name: 'Flat', gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] },
  { name: 'Bass Boost', gains: [8, 6, 4, 2, 0, 0, 0, 0, 0, 0] },
  { name: 'Treble Boost', gains: [0, 0, 0, 0, 0, 0, 2, 4, 6, 8] },
  { name: 'Vocal', gains: [-2, -1, 0, 2, 4, 4, 2, 0, -1, -2] },
  { name: 'Rock', gains: [5, 3, 0, -2, -3, -2, 0, 2, 4, 5] },
  { name: 'Pop', gains: [-1, 1, 3, 4, 3, 0, -1, -1, 1, 2] },
  { name: 'Jazz', gains: [3, 2, 0, 1, -1, -1, 0, 1, 2, 3] },
  { name: 'Electronic', gains: [5, 4, 1, 0, -2, 0, 1, 3, 4, 5] },
  { name: 'Classical', gains: [3, 2, 1, 0, 0, 0, 0, 1, 2, 3] },
  { name: 'Loudness', gains: [6, 4, 0, 0, -2, 0, -1, 0, 4, 6] },
];

// ─── Types ───

interface EqualizerViewProps {
  audioRef: React.RefObject<HTMLAudioElement | null>;
  isVisible: boolean;
  onClose: () => void;
}

// ─── Component ───

export default function EqualizerView({
  audioRef,
  isVisible,
  onClose,
}: EqualizerViewProps) {
  const [isEnabled, setIsEnabled] = useState(false);
  const [bandGains, setBandGains] = useState<number[]>(new Array(BAND_COUNT).fill(0));
  const [selectedPreset, setSelectedPreset] = useState<string>('Flat');
  const [showPresets, setShowPresets] = useState(false);

  // Web Audio API refs
  const audioContextRef = useRef<AudioContext | null>(null);
  const sourceRef = useRef<MediaElementAudioSourceNode | null>(null);
  const filtersRef = useRef<BiquadFilterNode[]>([]);
  const isConnectedRef = useRef(false);

  // Initialize Web Audio API
  const initAudioContext = useCallback(() => {
    const audio = audioRef.current;
    if (!audio || isConnectedRef.current) return;

    try {
      const ctx = new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)();
      audioContextRef.current = ctx;

      const source = ctx.createMediaElementSource(audio);
      sourceRef.current = source;

      // Create 10-band EQ using BiquadFilterNodes
      const filters: BiquadFilterNode[] = FREQUENCIES.map((freq, i) => {
        const filter = ctx.createBiquadFilter();
        if (i === 0) {
          filter.type = 'lowshelf';
        } else if (i === FREQUENCIES.length - 1) {
          filter.type = 'highshelf';
        } else {
          filter.type = 'peaking';
        }
        filter.frequency.value = freq;
        filter.gain.value = 0;
        filter.Q.value = 1.4;
        return filter;
      });

      // Chain: source -> filter[0] -> filter[1] -> ... -> filter[9] -> destination
      source.connect(filters[0]);
      for (let i = 0; i < filters.length - 1; i++) {
        filters[i].connect(filters[i + 1]);
      }
      filters[filters.length - 1].connect(ctx.destination);

      filtersRef.current = filters;
      isConnectedRef.current = true;
    } catch (err) {
      console.warn('Web Audio API not available for EQ:', err);
    }
  }, [audioRef]);

  // Apply gain values to filters
  useEffect(() => {
    if (!isConnectedRef.current) return;

    filtersRef.current.forEach((filter, i) => {
      filter.gain.value = isEnabled ? bandGains[i] : 0;
    });
  }, [bandGains, isEnabled]);

  // Initialize audio context when enabled for the first time
  useEffect(() => {
    if (isEnabled && !isConnectedRef.current) {
      initAudioContext();
    }
  }, [isEnabled, initAudioContext]);

  const handleGainChange = useCallback((bandIndex: number, value: number) => {
    setBandGains(prev => {
      const next = [...prev];
      // Snap to zero when close
      next[bandIndex] = Math.abs(value) < 0.8 ? 0 : Math.round(value * 2) / 2;
      return next;
    });
    setSelectedPreset('Custom');
  }, []);

  const handlePresetSelect = useCallback((preset: EQPreset) => {
    setBandGains([...preset.gains]);
    setSelectedPreset(preset.name);
    setShowPresets(false);
  }, []);

  const handleReset = useCallback(() => {
    setBandGains(new Array(BAND_COUNT).fill(0));
    setSelectedPreset('Flat');
  }, []);

  const handleToggleEnabled = useCallback(() => {
    setIsEnabled(prev => !prev);
  }, []);

  // Frequency response curve points for the SVG visualization
  const curvePoints = useMemo(() => {
    const width = 432; // inner width (480 - padding)
    const height = 80;
    const leftMargin = 30;
    const usableWidth = width - leftMargin;

    return bandGains.map((gain, i) => {
      const x = leftMargin + (i / (BAND_COUNT - 1)) * usableWidth;
      const normalized = (gain - MIN_GAIN) / (MAX_GAIN - MIN_GAIN);
      const y = height * (1 - normalized);
      return { x, y };
    });
  }, [bandGains]);

  const curvePath = useMemo(() => {
    if (curvePoints.length < 2) return '';

    let d = `M ${curvePoints[0].x},${curvePoints[0].y}`;

    for (let i = 0; i < curvePoints.length - 1; i++) {
      const p0 = i > 0 ? curvePoints[i - 1] : curvePoints[i];
      const p1 = curvePoints[i];
      const p2 = curvePoints[i + 1];
      const p3 = i + 2 < curvePoints.length ? curvePoints[i + 2] : curvePoints[i + 1];

      const cp1x = p1.x + (p2.x - p0.x) / 6;
      const cp1y = p1.y + (p2.y - p0.y) / 6;
      const cp2x = p2.x - (p3.x - p1.x) / 6;
      const cp2y = p2.y - (p3.y - p1.y) / 6;

      d += ` C ${cp1x},${cp1y} ${cp2x},${cp2y} ${p2.x},${p2.y}`;
    }

    return d;
  }, [curvePoints]);

  const filledPath = useMemo(() => {
    if (!curvePath || curvePoints.length === 0) return '';
    const height = 80;
    const zeroY = height / 2;
    const first = curvePoints[0];
    const last = curvePoints[curvePoints.length - 1];

    return `M ${first.x},${zeroY} L ${first.x},${first.y} ${curvePath.slice(curvePath.indexOf('C'))} L ${last.x},${zeroY} Z`;
  }, [curvePath, curvePoints]);

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          className="fixed right-0 bottom-[72px] w-[480px] bg-cinema-card/95 backdrop-blur-xl
                     border border-cinema-border rounded-tl-2xl shadow-2xl shadow-black/60 z-40 overflow-hidden flex flex-col"
          initial={{ opacity: 0, y: 20, x: 20 }}
          animate={{ opacity: 1, y: 0, x: 0 }}
          exit={{ opacity: 0, y: 20, x: 20 }}
          transition={{ duration: 0.25, ease: [0.4, 0, 0.2, 1] }}
        >
          {/* Header */}
          <div className="px-4 py-3 border-b border-cinema-border flex items-center justify-between">
            <h3 className="text-white text-sm font-semibold">Equalizer</h3>
            <div className="flex items-center gap-3">
              {/* Enable toggle */}
              <div className="flex items-center gap-2">
                <span className={`text-[10px] font-bold font-mono ${isEnabled ? 'text-cinema-gold' : 'text-cinema-text-dim'}`}>
                  {isEnabled ? 'ON' : 'OFF'}
                </span>
                <button
                  onClick={handleToggleEnabled}
                  className={`relative w-9 h-5 rounded-full transition-colors duration-200 ${isEnabled ? 'bg-cinema-gold' : 'bg-white/10'}`}
                >
                  <motion.div
                    className="absolute top-0.5 w-4 h-4 rounded-full bg-white shadow-sm"
                    animate={{ left: isEnabled ? 18 : 2 }}
                    transition={{ type: 'spring', stiffness: 500, damping: 30 }}
                  />
                </button>
              </div>

              <motion.button
                onClick={onClose}
                className="text-cinema-text-dim hover:text-white transition-colors duration-150 p-1"
                whileHover={{ scale: 1.1 }}
                whileTap={{ scale: 0.9 }}
              >
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </motion.button>
            </div>
          </div>

          {/* Frequency Response Curve */}
          <div className="px-4 pt-3">
            <svg width="100%" viewBox="0 0 432 80" className="overflow-visible">
              {/* Grid lines */}
              {[-12, -6, 0, 6, 12].map(dB => {
                const normalized = (dB - MIN_GAIN) / (MAX_GAIN - MIN_GAIN);
                const y = 80 * (1 - normalized);
                return (
                  <g key={dB}>
                    <line x1="30" y1={y} x2="432" y2={y}
                          stroke={dB === 0 ? 'rgba(255,255,255,0.15)' : 'rgba(255,255,255,0.06)'}
                          strokeWidth={dB === 0 ? 1 : 0.5} />
                    <text x="14" y={y + 3} textAnchor="middle"
                          fill="rgba(255,255,255,0.35)" fontSize="7" fontFamily="monospace">
                      {dB > 0 ? `+${dB}` : dB}
                    </text>
                  </g>
                );
              })}

              {/* Vertical grid lines at each frequency */}
              {curvePoints.map((pt, i) => (
                <line key={i} x1={pt.x} y1="0" x2={pt.x} y2="80"
                      stroke="rgba(255,255,255,0.06)" strokeWidth="0.5" />
              ))}

              {/* Curve fill */}
              {isEnabled && filledPath && (
                <path d={filledPath} fill="url(#eqGradient)" opacity="0.4" />
              )}

              {/* Curve line */}
              {isEnabled ? (
                <path d={curvePath} fill="none" stroke="url(#eqLineGradient)" strokeWidth="2" />
              ) : (
                <line x1="30" y1="40" x2="432" y2="40"
                      stroke="rgba(255,255,255,0.3)" strokeWidth="1.5" />
              )}

              <defs>
                <linearGradient id="eqGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#d4a017" stopOpacity="0.3" />
                  <stop offset="100%" stopColor="#d4a017" stopOpacity="0.02" />
                </linearGradient>
                <linearGradient id="eqLineGradient" x1="0" y1="0" x2="1" y2="0">
                  <stop offset="0%" stopColor="#d4a017" />
                  <stop offset="100%" stopColor="#d4a017" stopOpacity="0.6" />
                </linearGradient>
              </defs>
            </svg>
          </div>

          {/* Band Sliders */}
          <div className="px-2 pt-2 pb-3">
            <div className="flex items-end gap-0">
              {/* dB labels */}
              <div className="flex flex-col justify-between h-[170px] pb-5 w-7 flex-shrink-0">
                <span className="text-[8px] font-mono text-cinema-text-dim/50">+12</span>
                <span className="text-[8px] font-mono text-cinema-text-dim/50">0</span>
                <span className="text-[8px] font-mono text-cinema-text-dim/50">-12</span>
              </div>

              {/* Sliders */}
              {bandGains.map((gain, i) => (
                <div key={i} className="flex-1 flex flex-col items-center gap-1">
                  {/* Gain value label */}
                  <span className={`text-[8px] font-mono font-medium h-3
                                   ${isEnabled && Math.abs(gain) > 0.5
                                     ? 'text-cinema-gold'
                                     : 'text-cinema-text-dim/40'}`}>
                    {Math.abs(gain) < 0.1 ? '0' : `${gain > 0 ? '+' : ''}${Math.round(gain)}`}
                  </span>

                  {/* Vertical slider */}
                  <VerticalSlider
                    value={gain}
                    min={MIN_GAIN}
                    max={MAX_GAIN}
                    isEnabled={isEnabled}
                    onChange={(v) => handleGainChange(i, v)}
                  />

                  {/* Frequency label */}
                  <span className="text-[9px] font-medium text-cinema-text-dim mt-0.5">
                    {FREQUENCY_LABELS[i]}
                  </span>
                </div>
              ))}
            </div>
          </div>

          {/* Footer: Presets + Reset */}
          <div className="px-4 py-2.5 border-t border-cinema-border flex items-center justify-between">
            {/* Preset selector */}
            <div className="relative">
              <button
                onClick={() => setShowPresets(!showPresets)}
                className="flex items-center gap-2 px-3 py-1.5 bg-white/[0.06] hover:bg-white/[0.08]
                           rounded-md transition-colors duration-150"
              >
                <svg className="w-3 h-3 text-cinema-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                        d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
                </svg>
                <span className="text-white text-xs font-medium">{selectedPreset}</span>
                <svg className="w-2 h-2 text-cinema-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M19 9l-7 7-7-7" />
                </svg>
              </button>

              {/* Presets dropdown */}
              <AnimatePresence>
                {showPresets && (
                  <motion.div
                    className="absolute bottom-full left-0 mb-2 w-48 bg-cinema-surface border border-cinema-border
                               rounded-lg shadow-xl shadow-black/50 overflow-hidden z-50"
                    initial={{ opacity: 0, y: 10, scale: 0.95 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    exit={{ opacity: 0, y: 10, scale: 0.95 }}
                    transition={{ duration: 0.15 }}
                  >
                    {EQ_PRESETS.map((preset) => (
                      <button
                        key={preset.name}
                        onClick={() => handlePresetSelect(preset)}
                        className={`w-full text-left px-3 py-2 text-sm transition-colors duration-100
                                   hover:bg-white/[0.06]
                                   ${selectedPreset === preset.name
                                     ? 'text-cinema-gold bg-cinema-gold/10'
                                     : 'text-white'}`}
                      >
                        <span className="flex items-center justify-between">
                          {preset.name}
                          {selectedPreset === preset.name && (
                            <svg className="w-3.5 h-3.5 text-cinema-gold" fill="currentColor" viewBox="0 0 24 24">
                              <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
                            </svg>
                          )}
                        </span>
                      </button>
                    ))}
                  </motion.div>
                )}
              </AnimatePresence>
            </div>

            {/* Reset button */}
            <motion.button
              onClick={handleReset}
              className="flex items-center gap-1.5 px-3 py-1.5 bg-white/[0.04] hover:bg-white/[0.06]
                         rounded-md text-cinema-text-dim hover:text-white transition-all duration-150"
              whileTap={{ scale: 0.97 }}
            >
              <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                      d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              <span className="text-xs font-medium">Reset</span>
            </motion.button>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

// ─── Vertical Slider Sub-component ───

function VerticalSlider({
  value,
  min,
  max,
  isEnabled,
  onChange,
}: {
  value: number;
  min: number;
  max: number;
  isEnabled: boolean;
  onChange: (value: number) => void;
}) {
  const sliderRef = useRef<HTMLDivElement>(null);
  const [isDragging, setIsDragging] = useState(false);

  const trackHeight = 150;
  const normalized = (value - min) / (max - min);
  const thumbY = trackHeight * (1 - normalized);
  const zeroNormalized = (0 - min) / (max - min);
  const zeroY = trackHeight * (1 - zeroNormalized);

  const handlePointerDown = useCallback((e: React.PointerEvent) => {
    if (!isEnabled) return;
    e.preventDefault();
    setIsDragging(true);

    const rect = sliderRef.current?.getBoundingClientRect();
    if (!rect) return;

    const y = e.clientY - rect.top;
    const clamped = Math.max(0, Math.min(trackHeight, y));
    const norm = 1 - clamped / trackHeight;
    const newVal = min + norm * (max - min);
    onChange(newVal);

    (e.target as HTMLElement).setPointerCapture(e.pointerId);
  }, [isEnabled, min, max, onChange]);

  const handlePointerMove = useCallback((e: React.PointerEvent) => {
    if (!isDragging || !isEnabled) return;

    const rect = sliderRef.current?.getBoundingClientRect();
    if (!rect) return;

    const y = e.clientY - rect.top;
    const clamped = Math.max(0, Math.min(trackHeight, y));
    const norm = 1 - clamped / trackHeight;
    const newVal = min + norm * (max - min);
    onChange(newVal);
  }, [isDragging, isEnabled, min, max, onChange]);

  const handlePointerUp = useCallback(() => {
    setIsDragging(false);
  }, []);

  const fillTop = Math.min(thumbY, zeroY);
  const fillHeight = Math.abs(thumbY - zeroY);

  return (
    <div
      ref={sliderRef}
      className="relative w-full cursor-pointer touch-none"
      style={{ height: trackHeight }}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
    >
      {/* Track background */}
      <div className="absolute left-1/2 -translate-x-1/2 w-[3px] h-full rounded-full bg-white/10" />

      {/* Zero line */}
      <div
        className="absolute left-1/2 -translate-x-1/2 w-2.5 h-px bg-white/25"
        style={{ top: zeroY }}
      />

      {/* Active fill */}
      {isEnabled && Math.abs(value) > 0.1 && (
        <div
          className="absolute left-1/2 -translate-x-1/2 w-[3px] rounded-full bg-cinema-gold/60"
          style={{ top: fillTop, height: fillHeight }}
        />
      )}

      {/* Thumb */}
      <motion.div
        className={`absolute left-1/2 -translate-x-1/2 rounded-full
                    ${isEnabled ? 'bg-cinema-gold' : 'bg-cinema-text-dim/40'}`}
        style={{ top: thumbY - 6, width: isDragging ? 14 : 12, height: isDragging ? 14 : 12, marginLeft: isDragging ? -7 : -6 }}
        animate={{
          boxShadow: isEnabled && isDragging ? '0 0 8px rgba(212, 160, 23, 0.4)' : 'none',
        }}
      />
    </div>
  );
}
