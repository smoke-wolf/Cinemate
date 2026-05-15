#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "[cinemate] Creating virtual environment..."
    python3 -m venv venv
fi

source venv/bin/activate

echo "[cinemate] Installing dependencies..."
pip install -q -r requirements.txt

echo "[cinemate] Starting Cinemate server..."
python3 -m uvicorn main:app --host 0.0.0.0 --port 9876 --reload
