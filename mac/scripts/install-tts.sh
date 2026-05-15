#!/bin/bash
# install-tts.sh — Install Kokoro TTS engine for Cinemate audiobook generation
# Uses kokoro-onnx: high-quality neural TTS that runs locally on Apple Silicon
#
# Usage: ./install-tts.sh
# Installs to: ~/.cinemate/tts/

set -euo pipefail

TTS_DIR="$HOME/.cinemate/tts"
VENV_DIR="$TTS_DIR/venv"
MODEL_DIR="$TTS_DIR/models"
MARKER="$TTS_DIR/.installed"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[TTS]${NC} $1"; }
ok()    { echo -e "${GREEN}[TTS]${NC} $1"; }
warn()  { echo -e "${YELLOW}[TTS]${NC} $1"; }
err()   { echo -e "${RED}[TTS]${NC} $1"; }

# ----- Idempotent check -----
if [ -f "$MARKER" ] && [ -d "$VENV_DIR" ] && [ -f "$MODEL_DIR/kokoro-v1.0.onnx" ]; then
    ok "Kokoro TTS already installed at $TTS_DIR"
    ok "To force reinstall, remove $MARKER and run again."
    exit 0
fi

info "Installing Kokoro TTS engine..."
info "Destination: $TTS_DIR"
echo ""

# ----- Check prerequisites -----
info "Checking prerequisites..."

# Python 3
if ! command -v python3 &>/dev/null; then
    err "python3 not found. Please install Python 3.10+ (brew install python@3.12)"
    exit 1
fi

PYVER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYMAJOR=$(echo "$PYVER" | cut -d. -f1)
PYMINOR=$(echo "$PYVER" | cut -d. -f2)

if [ "$PYMAJOR" -lt 3 ] || ([ "$PYMAJOR" -eq 3 ] && [ "$PYMINOR" -lt 10 ]); then
    err "Python 3.10+ required (found $PYVER). Run: brew install python@3.12"
    exit 1
fi
ok "Python $PYVER found"

# ffmpeg for MP3 encoding
if ! command -v ffmpeg &>/dev/null; then
    warn "ffmpeg not found — needed for MP3 conversion."
    if command -v brew &>/dev/null; then
        info "Installing ffmpeg via Homebrew..."
        brew install ffmpeg
        ok "ffmpeg installed"
    else
        err "Please install ffmpeg: brew install ffmpeg"
        exit 1
    fi
else
    ok "ffmpeg found"
fi

# ----- Create directories -----
info "Creating directories..."
mkdir -p "$TTS_DIR"
mkdir -p "$MODEL_DIR"

# ----- Create Python virtual environment -----
info "Creating Python virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
ok "Virtual environment created"

# ----- Install Python packages -----
info "Installing kokoro-onnx and dependencies (this may take a minute)..."
pip install --quiet --upgrade pip
pip install --quiet kokoro-onnx soundfile numpy

ok "Python packages installed"

# ----- Download model files -----
# kokoro-v1.0.onnx (~87MB) and voices-v1.0.bin (~10MB) from the official release
MODEL_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx"
VOICES_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"

if [ ! -f "$MODEL_DIR/kokoro-v1.0.onnx" ]; then
    info "Downloading Kokoro model (~87 MB)..."
    curl -L --progress-bar -o "$MODEL_DIR/kokoro-v1.0.onnx" "$MODEL_URL"
    ok "Model downloaded"
else
    ok "Model already present"
fi

if [ ! -f "$MODEL_DIR/voices-v1.0.bin" ]; then
    info "Downloading voice pack (~10 MB)..."
    curl -L --progress-bar -o "$MODEL_DIR/voices-v1.0.bin" "$VOICES_URL"
    ok "Voice pack downloaded"
else
    ok "Voice pack already present"
fi

# ----- Create the TTS helper script -----
info "Creating TTS helper..."
cat > "$TTS_DIR/synthesize.py" << 'PYEOF'
#!/usr/bin/env python3
"""
Kokoro TTS synthesis helper for Cinemate.
Usage: python3 synthesize.py --text "Hello world" --output /path/to/output.wav [--voice af_bella] [--speed 1.0]
       python3 synthesize.py --file /path/to/text.txt --output /path/to/output.wav
"""

import argparse
import os
import sys
import soundfile as sf
import numpy as np

def get_model_dir():
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")

def synthesize(text, output_path, voice="af_bella", speed=1.0, lang="en-us"):
    from kokoro_onnx import Kokoro

    model_dir = get_model_dir()
    model_path = os.path.join(model_dir, "kokoro-v1.0.onnx")
    voices_path = os.path.join(model_dir, "voices-v1.0.bin")

    if not os.path.exists(model_path):
        print(f"ERROR: Model not found at {model_path}", file=sys.stderr)
        sys.exit(1)
    if not os.path.exists(voices_path):
        print(f"ERROR: Voices not found at {voices_path}", file=sys.stderr)
        sys.exit(1)

    kokoro = Kokoro(model_path, voices_path)

    # Split text into manageable chunks (~500 chars each to avoid quality degradation)
    chunks = split_text(text, max_chars=500)
    all_audio = []

    for i, chunk in enumerate(chunks):
        chunk = chunk.strip()
        if not chunk:
            continue
        try:
            samples, sample_rate = kokoro.create(chunk, voice=voice, speed=speed, lang=lang)
            all_audio.append(samples)
            # Add a small pause between chunks (0.3 seconds of silence)
            if i < len(chunks) - 1:
                silence = np.zeros(int(sample_rate * 0.3), dtype=samples.dtype)
                all_audio.append(silence)
        except Exception as e:
            print(f"WARNING: Failed to synthesize chunk {i+1}/{len(chunks)}: {e}", file=sys.stderr)
            continue

    if not all_audio:
        print("ERROR: No audio generated", file=sys.stderr)
        sys.exit(1)

    combined = np.concatenate(all_audio)
    sf.write(output_path, combined, sample_rate)
    duration_secs = len(combined) / sample_rate
    print(f"OK|{output_path}|{duration_secs:.1f}")

def split_text(text, max_chars=500):
    """Split text into chunks at sentence boundaries."""
    import re
    sentences = re.split(r'(?<=[.!?])\s+', text)
    chunks = []
    current = ""

    for sentence in sentences:
        if len(current) + len(sentence) + 1 > max_chars and current:
            chunks.append(current)
            current = sentence
        else:
            current = (current + " " + sentence).strip() if current else sentence

    if current:
        chunks.append(current)

    return chunks if chunks else [text]

def main():
    parser = argparse.ArgumentParser(description="Kokoro TTS synthesis")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--text", help="Text to synthesize")
    group.add_argument("--file", help="Path to text file to synthesize")
    parser.add_argument("--output", required=True, help="Output WAV path")
    parser.add_argument("--voice", default="af_bella", help="Voice name (default: af_bella)")
    parser.add_argument("--speed", type=float, default=1.0, help="Speed factor (default: 1.0)")
    parser.add_argument("--lang", default="en-us", help="Language code (default: en-us)")
    args = parser.parse_args()

    if args.file:
        with open(args.file, 'r', encoding='utf-8') as f:
            text = f.read()
    else:
        text = args.text

    if not text or not text.strip():
        print("ERROR: Empty text", file=sys.stderr)
        sys.exit(1)

    synthesize(text, args.output, voice=args.voice, speed=args.speed, lang=args.lang)

if __name__ == "__main__":
    main()
PYEOF
chmod +x "$TTS_DIR/synthesize.py"

# ----- Verify installation -----
info "Verifying installation..."
TEST_OUTPUT="$TTS_DIR/test_output.wav"
"$VENV_DIR/bin/python3" "$TTS_DIR/synthesize.py" \
    --text "Kokoro TTS installed successfully for Cinemate." \
    --output "$TEST_OUTPUT" \
    --voice af_bella 2>&1 || {
    err "Installation verification failed!"
    err "Try running manually: $VENV_DIR/bin/python3 $TTS_DIR/synthesize.py --text 'test' --output /tmp/test.wav"
    exit 1
}

if [ -f "$TEST_OUTPUT" ]; then
    ok "Verification passed"
    rm -f "$TEST_OUTPUT"
else
    err "Verification failed: no output file created"
    exit 1
fi

# ----- Mark as installed -----
date -u +"%Y-%m-%dT%H:%M:%SZ" > "$MARKER"

echo ""
ok "======================================"
ok " Kokoro TTS installed successfully!"
ok "======================================"
ok ""
ok " Location:  $TTS_DIR"
ok " Model:     Kokoro 82M v1.0 (ONNX)"
ok " Voice:     af_bella (natural female)"
ok " Size:      ~100 MB total"
ok ""
ok " Available voices:"
ok "   af_bella, af_nicole, af_sarah, af_sky (female)"
ok "   am_adam, am_michael, am_eric, am_liam (male)"
ok "   bf_emma, bf_isabella, bf_lily (British female)"
ok "   bm_george, bm_lewis, bm_daniel (British male)"
ok ""
ok " Ready to generate audiobooks!"
