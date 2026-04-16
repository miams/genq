#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_FILE="${1:-$ROOT_DIR/screencast/genq-demo.cast}"

mkdir -p "$(dirname "$OUT_FILE")"

cd "$ROOT_DIR"

asciinema record \
  --overwrite \
  --headless \
  --idle-time-limit 1.2 \
  --window-size 110x32 \
  --title "GenQuery demo" \
  --command "$ROOT_DIR/screencast/genq-demo-session.sh" \
  "$OUT_FILE"

printf 'Wrote %s\n' "$OUT_FILE"
