#!/bin/bash
# book-to-audio.sh — Convert ePub/PDF books to audiobook using Kokoro TTS
#
# Usage: book-to-audio.sh <input.epub|input.pdf> <output-dir> [--voice af_bella] [--speed 1.0]
#
# Outputs:
#   <output-dir>/chapter_01.mp3
#   <output-dir>/chapter_02.mp3
#   ...
#   <output-dir>/audiobook.json  (metadata: title, chapters, durations)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()     { echo -e "${BLUE}[AUDIO]${NC} $1"; }
ok()       { echo -e "${GREEN}[AUDIO]${NC} $1"; }
warn()     { echo -e "${YELLOW}[AUDIO]${NC} $1"; }
err()      { echo -e "${RED}[AUDIO]${NC} $1"; }
progress() { echo -e "${CYAN}[PROGRESS]${NC} $1"; }

TTS_DIR="$HOME/.cinemate/tts"
VENV_PYTHON="$TTS_DIR/venv/bin/python3"
SYNTH_SCRIPT="$TTS_DIR/synthesize.py"

# ----- Argument parsing -----
if [ $# -lt 2 ]; then
    echo "Usage: $0 <input.epub|input.pdf> <output-dir> [--voice af_bella] [--speed 1.0]"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_DIR="$2"
shift 2

VOICE="af_bella"
SPEED="1.0"

while [ $# -gt 0 ]; do
    case "$1" in
        --voice) VOICE="$2"; shift 2 ;;
        --speed) SPEED="$2"; shift 2 ;;
        *) err "Unknown option: $1"; exit 1 ;;
    esac
done

# ----- Validation -----
if [ ! -f "$INPUT_FILE" ]; then
    err "Input file not found: $INPUT_FILE"
    exit 1
fi

if [ ! -f "$VENV_PYTHON" ]; then
    err "TTS engine not installed. Run install-tts.sh first."
    exit 1
fi

if ! command -v ffmpeg &>/dev/null; then
    err "ffmpeg not found. Run: brew install ffmpeg"
    exit 1
fi

EXT="${INPUT_FILE##*.}"
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

if [[ "$EXT_LOWER" != "epub" && "$EXT_LOWER" != "pdf" ]]; then
    err "Unsupported format: $EXT (only epub and pdf are supported)"
    exit 1
fi

# ----- Setup -----
mkdir -p "$OUTPUT_DIR"
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

BOOK_NAME=$(basename "$INPUT_FILE" ".$EXT")
info "Converting: $BOOK_NAME"
info "Format: $EXT_LOWER | Voice: $VOICE | Speed: $SPEED"
info "Output: $OUTPUT_DIR"
echo ""

# ----- Extract text by chapters -----
progress "STAGE|extract|Extracting text from book..."

"$VENV_PYTHON" - "$INPUT_FILE" "$WORK_DIR" "$EXT_LOWER" << 'PYEXTRACT'
import sys
import os
import json
import re
import html
from pathlib import Path

input_file = sys.argv[1]
work_dir = sys.argv[2]
fmt = sys.argv[3]

chapters = []

def clean_text(text):
    """Clean extracted text for TTS."""
    # Remove HTML tags
    text = re.sub(r'<[^>]+>', ' ', text)
    # Decode HTML entities
    text = html.unescape(text)
    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text)
    # Remove weird characters but keep punctuation
    text = re.sub(r'[^\w\s.,;:!?\'\"()\-—–‘’“”]', '', text)
    # Normalize dashes and quotes
    text = text.replace('—', ' -- ').replace('–', ' - ')
    text = text.replace('‘', "'").replace('’', "'")
    text = text.replace('“', '"').replace('”', '"')
    return text.strip()

def extract_epub(filepath):
    """Extract chapters from an ePub file."""
    import zipfile
    import xml.etree.ElementTree as ET

    chapters = []

    with zipfile.ZipFile(filepath, 'r') as zf:
        # Find the OPF file (content.opf)
        opf_path = None
        for name in zf.namelist():
            if name.endswith('.opf'):
                opf_path = name
                break

        if not opf_path:
            # Try container.xml
            try:
                container = ET.fromstring(zf.read('META-INF/container.xml'))
                ns = {'c': 'urn:oasis:names:tc:opendocument:xmlns:container'}
                rootfile = container.find('.//c:rootfile', ns)
                if rootfile is not None:
                    opf_path = rootfile.get('full-path')
            except:
                pass

        if not opf_path:
            # Fallback: find all HTML/XHTML files
            html_files = sorted([n for n in zf.namelist()
                               if n.endswith(('.html', '.xhtml', '.htm'))
                               and 'toc' not in n.lower()
                               and 'nav' not in n.lower()])
            for i, hf in enumerate(html_files):
                try:
                    content = zf.read(hf).decode('utf-8', errors='ignore')
                    text = clean_text(content)
                    if len(text) > 100:
                        chapters.append({
                            'title': f'Chapter {i+1}',
                            'text': text,
                            'file': hf
                        })
                except:
                    continue
            return chapters

        # Parse OPF to get spine order
        opf_dir = os.path.dirname(opf_path)
        opf_content = zf.read(opf_path).decode('utf-8', errors='ignore')
        opf_tree = ET.fromstring(opf_content)

        # Get namespace
        ns_opf = ''
        if opf_tree.tag.startswith('{'):
            ns_opf = opf_tree.tag.split('}')[0] + '}'

        # Build manifest (id -> href)
        manifest = {}
        for item in opf_tree.iter(f'{ns_opf}item'):
            item_id = item.get('id', '')
            href = item.get('href', '')
            media_type = item.get('media-type', '')
            if 'html' in media_type or 'xml' in media_type:
                manifest[item_id] = href

        # Get spine order
        spine_ids = []
        for itemref in opf_tree.iter(f'{ns_opf}itemref'):
            idref = itemref.get('idref', '')
            if idref in manifest:
                spine_ids.append(idref)

        # If no spine, use manifest order
        if not spine_ids:
            spine_ids = list(manifest.keys())

        # Extract text from each spine item
        chapter_num = 0
        for item_id in spine_ids:
            href = manifest[item_id]
            # Resolve path relative to OPF directory
            full_path = os.path.normpath(os.path.join(opf_dir, href)) if opf_dir else href

            try:
                content = zf.read(full_path).decode('utf-8', errors='ignore')
            except KeyError:
                # Try without normalization
                try:
                    content = zf.read(href).decode('utf-8', errors='ignore')
                except:
                    continue

            text = clean_text(content)

            # Skip very short content (likely title pages, TOC, etc.)
            if len(text) < 100:
                continue

            # Try to extract chapter title from heading tags
            title_match = re.search(r'<h[1-3][^>]*>(.*?)</h[1-3]>', content, re.IGNORECASE | re.DOTALL)
            if title_match:
                title = clean_text(title_match.group(1))
                if len(title) > 80:
                    title = title[:77] + '...'
            else:
                chapter_num += 1
                title = f'Chapter {chapter_num}'

            chapters.append({
                'title': title,
                'text': text,
                'file': full_path
            })

    return chapters

def extract_pdf(filepath):
    """Extract text from PDF, splitting into chapters by page ranges."""
    # Use python's built-in capabilities + a simple PDF text extractor
    # We'll try subprocess with textutil (macOS built-in) first, then fall back to basic parsing
    import subprocess

    chapters = []

    # Try using macOS built-in textutil to convert PDF to text
    try:
        result = subprocess.run(
            ['textutil', '-convert', 'txt', '-stdout', filepath],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode == 0 and len(result.stdout.strip()) > 100:
            full_text = result.stdout
        else:
            raise Exception("textutil failed or produced too little text")
    except:
        # Fallback: try mdimport/spotlight metadata or basic PDF parsing
        try:
            result = subprocess.run(
                ['mdimport', '-d1', filepath],
                capture_output=True, text=True, timeout=30
            )
        except:
            pass

        # Last resort: read raw PDF and extract text between stream markers
        full_text = ""
        try:
            with open(filepath, 'rb') as f:
                raw = f.read()
            # Simple extraction of text from PDF streams
            text_parts = []
            for match in re.finditer(rb'\((.*?)\)', raw):
                try:
                    decoded = match.group(1).decode('utf-8', errors='ignore')
                    if len(decoded) > 1 and any(c.isalpha() for c in decoded):
                        text_parts.append(decoded)
                except:
                    continue
            full_text = ' '.join(text_parts)
        except:
            full_text = ""

    if not full_text or len(full_text.strip()) < 100:
        print("ERROR: Could not extract text from PDF", file=sys.stderr)
        sys.exit(1)

    # Split into chapters by looking for chapter headings or by page count
    # First try: split by chapter headings
    chapter_pattern = re.compile(
        r'\n\s*(Chapter\s+\d+[^\n]*|CHAPTER\s+\d+[^\n]*|Part\s+\d+[^\n]*|PART\s+\d+[^\n]*)\s*\n',
        re.IGNORECASE
    )

    splits = list(chapter_pattern.finditer(full_text))

    if len(splits) >= 2:
        # Split by detected chapter headings
        for i, match in enumerate(splits):
            title = match.group(1).strip()
            start = match.end()
            end = splits[i + 1].start() if i + 1 < len(splits) else len(full_text)
            text = clean_text(full_text[start:end])
            if len(text) > 100:
                chapters.append({'title': title, 'text': text, 'file': f'chapter_{i+1}'})
    else:
        # Split by roughly equal portions (~5000 chars each for manageable TTS chunks)
        chunk_size = 5000
        text = clean_text(full_text)
        for i in range(0, len(text), chunk_size):
            chunk = text[i:i + chunk_size]
            # Try to break at sentence boundary
            if i + chunk_size < len(text):
                last_period = chunk.rfind('. ')
                if last_period > chunk_size * 0.5:
                    chunk = chunk[:last_period + 1]
            if len(chunk.strip()) > 50:
                chapters.append({
                    'title': f'Section {len(chapters) + 1}',
                    'text': chunk.strip(),
                    'file': f'section_{len(chapters) + 1}'
                })

    return chapters

# Main extraction
if fmt == 'epub':
    chapters = extract_epub(input_file)
elif fmt == 'pdf':
    chapters = extract_pdf(input_file)
else:
    print(f"ERROR: Unsupported format: {fmt}", file=sys.stderr)
    sys.exit(1)

if not chapters:
    print("ERROR: No chapters extracted from book", file=sys.stderr)
    sys.exit(1)

# Write chapter text files and manifest
manifest = []
for i, chapter in enumerate(chapters):
    chap_file = os.path.join(work_dir, f'chapter_{i+1:03d}.txt')
    with open(chap_file, 'w', encoding='utf-8') as f:
        f.write(chapter['text'])
    manifest.append({
        'index': i + 1,
        'title': chapter['title'],
        'text_file': chap_file,
        'char_count': len(chapter['text'])
    })

manifest_path = os.path.join(work_dir, 'manifest.json')
with open(manifest_path, 'w') as f:
    json.dump(manifest, f, indent=2)

print(f"EXTRACTED|{len(chapters)}|chapters")
for ch in manifest:
    print(f"CHAPTER|{ch['index']}|{ch['title']}|{ch['char_count']} chars")
PYEXTRACT

if [ $? -ne 0 ]; then
    err "Text extraction failed"
    exit 1
fi

# ----- Read manifest -----
MANIFEST="$WORK_DIR/manifest.json"
if [ ! -f "$MANIFEST" ]; then
    err "No manifest generated — text extraction failed"
    exit 1
fi

TOTAL_CHAPTERS=$("$VENV_PYTHON" -c "import json; print(len(json.load(open('$MANIFEST'))))")
info "Extracted $TOTAL_CHAPTERS chapters"
echo ""

# ----- Synthesize each chapter -----
progress "STAGE|synthesize|Generating audio for $TOTAL_CHAPTERS chapters..."

CHAPTER_META="[]"
COMPLETED=0

for i in $(seq 1 "$TOTAL_CHAPTERS"); do
    PADDED=$(printf "%03d" "$i")
    TEXT_FILE="$WORK_DIR/chapter_${PADDED}.txt"
    WAV_FILE="$WORK_DIR/chapter_${PADDED}.wav"
    MP3_FILE="$OUTPUT_DIR/chapter_${PADDED}.mp3"

    # Get chapter title from manifest
    CHAPTER_TITLE=$("$VENV_PYTHON" -c "
import json
m = json.load(open('$MANIFEST'))
for ch in m:
    if ch['index'] == $i:
        print(ch['title'])
        break
")

    progress "CHAPTER|$i|$TOTAL_CHAPTERS|$CHAPTER_TITLE"

    # Synthesize to WAV
    SYNTH_RESULT=$("$VENV_PYTHON" "$SYNTH_SCRIPT" \
        --file "$TEXT_FILE" \
        --output "$WAV_FILE" \
        --voice "$VOICE" \
        --speed "$SPEED" 2>&1) || {
        warn "Failed to synthesize chapter $i ($CHAPTER_TITLE), skipping"
        continue
    }

    # Extract duration from synthesize output
    DURATION=$(echo "$SYNTH_RESULT" | grep "^OK|" | cut -d'|' -f3)
    if [ -z "$DURATION" ]; then
        DURATION="0"
    fi

    # Convert WAV to MP3
    ffmpeg -y -i "$WAV_FILE" \
        -codec:a libmp3lame -qscale:a 2 \
        -metadata title="$CHAPTER_TITLE" \
        -metadata album="$BOOK_NAME" \
        -metadata track="$i/$TOTAL_CHAPTERS" \
        "$MP3_FILE" 2>/dev/null

    if [ -f "$MP3_FILE" ]; then
        MP3_SIZE=$(stat -f%z "$MP3_FILE" 2>/dev/null || echo "0")
        ok "  Chapter $i: $CHAPTER_TITLE (${DURATION}s, $(echo "scale=1; $MP3_SIZE / 1048576" | bc 2>/dev/null || echo '?') MB)"
        COMPLETED=$((COMPLETED + 1))
    fi

    # Clean up WAV to save space
    rm -f "$WAV_FILE"
done

echo ""

# ----- Generate metadata JSON -----
progress "STAGE|metadata|Writing audiobook metadata..."

"$VENV_PYTHON" - "$INPUT_FILE" "$OUTPUT_DIR" "$MANIFEST" "$VOICE" "$SPEED" "$BOOK_NAME" << 'PYMETA'
import sys
import os
import json
import subprocess
from datetime import datetime

input_file = sys.argv[1]
output_dir = sys.argv[2]
manifest_path = sys.argv[3]
voice = sys.argv[4]
speed = sys.argv[5]
book_name = sys.argv[6]

manifest = json.load(open(manifest_path))

chapters = []
total_duration = 0.0

for ch in manifest:
    padded = f"{ch['index']:03d}"
    mp3_path = os.path.join(output_dir, f"chapter_{padded}.mp3")

    if not os.path.exists(mp3_path):
        continue

    # Get duration via ffprobe
    duration = 0.0
    try:
        result = subprocess.run(
            ['ffprobe', '-v', 'quiet', '-show_entries', 'format=duration',
             '-of', 'default=noprint_wrappers=1:nokey=1', mp3_path],
            capture_output=True, text=True, timeout=10
        )
        duration = float(result.stdout.strip())
    except:
        pass

    file_size = os.path.getsize(mp3_path)
    total_duration += duration

    chapters.append({
        'index': ch['index'],
        'title': ch['title'],
        'filename': f"chapter_{padded}.mp3",
        'duration_seconds': round(duration, 1),
        'duration_display': f"{int(duration // 60)}:{int(duration % 60):02d}",
        'file_size': file_size,
        'char_count': ch['char_count']
    })

metadata = {
    'title': book_name,
    'source_file': input_file,
    'generated_at': datetime.utcnow().isoformat() + 'Z',
    'tts_engine': 'kokoro-onnx-v1.0',
    'voice': voice,
    'speed': float(speed),
    'total_chapters': len(chapters),
    'total_duration_seconds': round(total_duration, 1),
    'total_duration_display': f"{int(total_duration // 3600)}:{int((total_duration % 3600) // 60):02d}:{int(total_duration % 60):02d}",
    'chapters': chapters
}

meta_path = os.path.join(output_dir, 'audiobook.json')
with open(meta_path, 'w') as f:
    json.dump(metadata, f, indent=2)

print(f"METADATA|{meta_path}")
print(f"TOTAL|{len(chapters)}|{metadata['total_duration_display']}")
PYMETA

echo ""
ok "======================================"
ok " Audiobook generation complete!"
ok "======================================"
ok ""
ok " Book:     $BOOK_NAME"
ok " Chapters: $COMPLETED of $TOTAL_CHAPTERS"
ok " Output:   $OUTPUT_DIR"
ok " Voice:    $VOICE"
ok ""
ok " Files:"
for f in "$OUTPUT_DIR"/chapter_*.mp3; do
    [ -f "$f" ] && ok "   $(basename "$f")"
done
ok "   audiobook.json"
ok ""
progress "DONE|$COMPLETED|$TOTAL_CHAPTERS"
