#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/Assets/noun-candle-4420273.png"
OUTPUT="$ROOT_DIR/Assets/AppIcon.png"
WORK_DIR="$ROOT_DIR/.build/app-icon"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

# Keep the winning candle artwork by itself. The transparent canvas lets macOS
# place the mark naturally alongside the other minimal Dock icons.
magick "$SOURCE" -alpha set -strip "$OUTPUT"
