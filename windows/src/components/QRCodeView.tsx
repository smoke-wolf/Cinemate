import React, { useMemo, useState } from 'react';
import { motion } from 'framer-motion';

// ─── Minimal QR Code Generator (Mode: Byte, ECC: M, Version: auto 1-10) ───

// Galois field tables for GF(256) with polynomial 0x11d
const GF_EXP = new Uint8Array(512);
const GF_LOG = new Uint8Array(256);
(function initGF() {
  let x = 1;
  for (let i = 0; i < 255; i++) {
    GF_EXP[i] = x;
    GF_LOG[x] = i;
    x = (x << 1) ^ (x >= 128 ? 0x11d : 0);
  }
  for (let i = 255; i < 512; i++) GF_EXP[i] = GF_EXP[i - 255];
})();

function gfMul(a: number, b: number): number {
  if (a === 0 || b === 0) return 0;
  return GF_EXP[GF_LOG[a] + GF_LOG[b]];
}

function rsGenPoly(nsym: number): Uint8Array {
  let g = new Uint8Array([1]);
  for (let i = 0; i < nsym; i++) {
    const ng = new Uint8Array(g.length + 1);
    for (let j = 0; j < g.length; j++) {
      ng[j] ^= g[j];
      ng[j + 1] ^= gfMul(g[j], GF_EXP[i]);
    }
    g = ng;
  }
  return g;
}

function rsEncode(data: Uint8Array, nsym: number): Uint8Array {
  const gen = rsGenPoly(nsym);
  const out = new Uint8Array(data.length + nsym);
  out.set(data);
  for (let i = 0; i < data.length; i++) {
    const coef = out[i];
    if (coef !== 0) {
      for (let j = 0; j < gen.length; j++) {
        out[i + j] ^= gfMul(gen[j], coef);
      }
    }
  }
  return out.slice(data.length);
}

// Version capacities for byte mode, ECC level M
const VERSION_CAPS_M = [0, 14, 26, 42, 62, 84, 106, 122, 152, 180, 213];

// EC codewords per block for ECC M, versions 1-10
const EC_CODEWORDS_M = [0, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26];

// Number of EC blocks for ECC M, versions 1-10
const EC_BLOCKS_M = [0, 1, 1, 1, 2, 2, 4, 4, 4, 4, 4]; // simplified — group 1 only for small versions

// Total codewords per version
const TOTAL_CODEWORDS = [0, 26, 44, 70, 100, 134, 172, 196, 242, 292, 346];

function chooseVersion(dataLen: number): number {
  for (let v = 1; v <= 10; v++) {
    if (dataLen <= VERSION_CAPS_M[v]) return v;
  }
  return 10; // clamp
}

// Alignment pattern centers per version
const ALIGN_CENTERS: number[][] = [
  [], [], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34],
  [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50],
];

function encodeQR(text: string): boolean[][] | null {
  const bytes = new TextEncoder().encode(text);
  const dataLen = bytes.length;
  if (dataLen > VERSION_CAPS_M[10]) return null;

  const version = chooseVersion(dataLen);
  const size = 17 + version * 4;

  // Build data stream: mode(4) + charcount(8 or 16) + data + terminator + padding
  const totalCodewords = TOTAL_CODEWORDS[version];
  const ecCodewordsPerBlock = EC_CODEWORDS_M[version];
  const numBlocks = EC_BLOCKS_M[version];
  const totalEC = ecCodewordsPerBlock * numBlocks;
  const dataCodewords = totalCodewords - totalEC;

  // Bit stream
  const bits: number[] = [];
  const pushBits = (val: number, len: number) => {
    for (let i = len - 1; i >= 0; i--) bits.push((val >> i) & 1);
  };

  pushBits(0b0100, 4); // byte mode
  pushBits(dataLen, version >= 10 ? 16 : 8); // char count
  for (const b of bytes) pushBits(b, 8);

  // Terminator
  const maxBits = dataCodewords * 8;
  const termLen = Math.min(4, maxBits - bits.length);
  pushBits(0, termLen);

  // Pad to byte boundary
  while (bits.length % 8 !== 0) bits.push(0);

  // Pad codewords
  const padBytes = [0xec, 0x11];
  let padIdx = 0;
  while (bits.length < maxBits) {
    pushBits(padBytes[padIdx % 2], 8);
    padIdx++;
  }

  // Convert to bytes
  const dataBytes = new Uint8Array(dataCodewords);
  for (let i = 0; i < dataCodewords; i++) {
    let byte = 0;
    for (let b = 0; b < 8; b++) byte = (byte << 1) | (bits[i * 8 + b] || 0);
    dataBytes[i] = byte;
  }

  // RS encode blocks
  const blockSize = Math.floor(dataCodewords / numBlocks);
  const longBlocks = dataCodewords % numBlocks;
  const dataBlocks: Uint8Array[] = [];
  const ecBlocks: Uint8Array[] = [];
  let offset = 0;
  for (let b = 0; b < numBlocks; b++) {
    const sz = blockSize + (b >= numBlocks - longBlocks ? 1 : 0);
    const block = dataBytes.slice(offset, offset + sz);
    dataBlocks.push(block);
    ecBlocks.push(rsEncode(block, ecCodewordsPerBlock));
    offset += sz;
  }

  // Interleave
  const interleaved: number[] = [];
  const maxDataLen = blockSize + (longBlocks > 0 ? 1 : 0);
  for (let i = 0; i < maxDataLen; i++) {
    for (let b = 0; b < numBlocks; b++) {
      if (i < dataBlocks[b].length) interleaved.push(dataBlocks[b][i]);
    }
  }
  for (let i = 0; i < ecCodewordsPerBlock; i++) {
    for (let b = 0; b < numBlocks; b++) {
      interleaved.push(ecBlocks[b][i]);
    }
  }

  // Create matrix
  const matrix: (boolean | null)[][] = Array.from({ length: size }, () => Array(size).fill(null));
  const reserved: boolean[][] = Array.from({ length: size }, () => Array(size).fill(false));

  const setModule = (r: number, c: number, val: boolean, isReserved = true) => {
    if (r >= 0 && r < size && c >= 0 && c < size) {
      matrix[r][c] = val;
      if (isReserved) reserved[r][c] = true;
    }
  };

  // Finder patterns
  const drawFinder = (row: number, col: number) => {
    for (let dr = -1; dr <= 7; dr++) {
      for (let dc = -1; dc <= 7; dc++) {
        const r = row + dr, c = col + dc;
        if (r < 0 || r >= size || c < 0 || c >= size) continue;
        const isBlack =
          (dr >= 0 && dr <= 6 && (dc === 0 || dc === 6)) ||
          (dc >= 0 && dc <= 6 && (dr === 0 || dr === 6)) ||
          (dr >= 2 && dr <= 4 && dc >= 2 && dc <= 4);
        setModule(r, c, isBlack);
      }
    }
  };

  drawFinder(0, 0);
  drawFinder(0, size - 7);
  drawFinder(size - 7, 0);

  // Alignment patterns
  if (version >= 2) {
    const centers = ALIGN_CENTERS[version];
    for (const cr of centers) {
      for (const cc of centers) {
        if (reserved[cr]?.[cc]) continue;
        for (let dr = -2; dr <= 2; dr++) {
          for (let dc = -2; dc <= 2; dc++) {
            const isBlack = Math.abs(dr) === 2 || Math.abs(dc) === 2 || (dr === 0 && dc === 0);
            setModule(cr + dr, cc + dc, isBlack);
          }
        }
      }
    }
  }

  // Timing patterns
  for (let i = 8; i < size - 8; i++) {
    if (!reserved[6][i]) setModule(6, i, i % 2 === 0);
    if (!reserved[i][6]) setModule(i, 6, i % 2 === 0);
  }

  // Dark module
  setModule(size - 8, 8, true);

  // Reserve format info areas
  for (let i = 0; i < 8; i++) {
    if (!reserved[8][i]) { reserved[8][i] = true; }
    if (!reserved[i][8]) { reserved[i][8] = true; }
    if (!reserved[8][size - 1 - i]) { reserved[8][size - 1 - i] = true; }
    if (!reserved[size - 1 - i][8]) { reserved[size - 1 - i][8] = true; }
  }
  reserved[8][8] = true;

  // Reserve version info (v >= 7 only, skip for our range)

  // Place data bits
  const interleavedBits: number[] = [];
  for (const byte of interleaved) {
    for (let b = 7; b >= 0; b--) interleavedBits.push((byte >> b) & 1);
  }

  let bitIdx = 0;
  let upward = true;
  for (let right = size - 1; right >= 1; right -= 2) {
    if (right === 6) right = 5; // Skip timing column
    const rows = upward ? Array.from({ length: size }, (_, i) => size - 1 - i) : Array.from({ length: size }, (_, i) => i);
    for (const row of rows) {
      for (const colOffset of [0, -1]) {
        const col = right + colOffset;
        if (col < 0 || col >= size) continue;
        if (reserved[row][col]) continue;
        matrix[row][col] = bitIdx < interleavedBits.length ? interleavedBits[bitIdx] === 1 : false;
        bitIdx++;
      }
    }
    upward = !upward;
  }

  // Apply mask pattern 0 (checkerboard: (row + col) % 2 === 0) and format info
  // Mask
  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      if (!reserved[r][c]) {
        if ((r + c) % 2 === 0) {
          matrix[r][c] = !matrix[r][c];
        }
      }
    }
  }

  // Format info for mask 0, ECC M: precomputed
  // ECC level M = 00, mask 0 = 000 -> data = 00000 -> format = 101010000010010
  const formatBits = [1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0];

  // Place format info
  const formatPositions1: [number, number][] = [
    [8, 0], [8, 1], [8, 2], [8, 3], [8, 4], [8, 5],
    [8, 7], [8, 8], [7, 8], [5, 8], [4, 8], [3, 8],
    [2, 8], [1, 8], [0, 8],
  ];
  const formatPositions2: [number, number][] = [
    [size - 1, 8], [size - 2, 8], [size - 3, 8], [size - 4, 8],
    [size - 5, 8], [size - 6, 8], [size - 7, 8],
    [8, size - 8], [8, size - 7], [8, size - 6], [8, size - 5],
    [8, size - 4], [8, size - 3], [8, size - 2], [8, size - 1],
  ];

  for (let i = 0; i < 15; i++) {
    const val = formatBits[i] === 1;
    const [r1, c1] = formatPositions1[i];
    matrix[r1][c1] = val;
    const [r2, c2] = formatPositions2[i];
    matrix[r2][c2] = val;
  }

  return matrix.map((row) => row.map((cell) => cell === true));
}

// ─── SVG Renderer ───

function QRCodeSVG({ data, size = 160, color = '#d4a017' }: { data: boolean[][]; size: number; color?: string }) {
  const modules = data.length;
  const cellSize = size / (modules + 2); // 1-module quiet zone
  const offset = cellSize; // quiet zone

  const paths: string[] = [];
  for (let r = 0; r < modules; r++) {
    for (let c = 0; c < modules; c++) {
      if (data[r][c]) {
        const x = offset + c * cellSize;
        const y = offset + r * cellSize;
        paths.push(`M${x},${y}h${cellSize}v${cellSize}h-${cellSize}z`);
      }
    }
  }

  return (
    <svg
      width={size}
      height={size}
      viewBox={`0 0 ${size} ${size}`}
      className="rounded-lg"
      style={{ backgroundColor: '#ffffff' }}
    >
      <path d={paths.join('')} fill={color} />
    </svg>
  );
}

// ─── Component ───

interface QRCodeViewProps {
  url: string;
  size?: number;
}

export default function QRCodeView({ url, size = 160 }: QRCodeViewProps) {
  const [copied, setCopied] = useState(false);

  const qrData = useMemo(() => {
    if (!url) return null;
    return encodeQR(url);
  }, [url]);

  const copyUrl = () => {
    navigator.clipboard.writeText(url).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  };

  return (
    <motion.div
      className="flex flex-col items-center gap-4"
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.3 }}
    >
      {qrData ? (
        <motion.div
          className="p-2 rounded-xl bg-white shadow-lg shadow-cinema-gold/10"
          whileHover={{ scale: 1.03 }}
          transition={{ duration: 0.2 }}
        >
          <QRCodeSVG data={qrData} size={size} color="#1a1a1a" />
        </motion.div>
      ) : (
        <div
          className="flex items-center justify-center rounded-xl bg-white/[0.06] border border-cinema-border"
          style={{ width: size, height: size }}
        >
          <div className="text-center">
            <svg className="w-8 h-8 mx-auto mb-2 text-cinema-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h2M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z" />
            </svg>
            <span className="text-cinema-text-dim text-xs">QR unavailable</span>
          </div>
        </div>
      )}

      {/* URL display + copy */}
      <div className="flex items-center gap-2 max-w-[280px]">
        <span className="text-cinema-text-secondary text-xs font-mono truncate">{url || 'No URL'}</span>
        {url && (
          <motion.button
            onClick={copyUrl}
            className="shrink-0 px-2.5 py-1 text-[11px] font-medium rounded-md
                       bg-cinema-gold/10 text-cinema-gold hover:bg-cinema-gold/20
                       transition-colors duration-200"
            whileTap={{ scale: 0.95 }}
          >
            {copied ? 'Copied!' : 'Copy'}
          </motion.button>
        )}
      </div>
    </motion.div>
  );
}
