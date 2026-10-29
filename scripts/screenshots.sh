#!/bin/bash
# Renders the README screenshots into docs/screenshots/ using ZenPad's demo mode.
# Demo mode uses sample notes in a temporary folder and never touches your real notes or settings.
#
#   scripts/screenshots.sh [path/to/ZenPad.app]
#
# Needs Screen Recording permission for your terminal (System Settings > Privacy & Security).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build/dd/Build/Products/Debug/ZenPad.app}"
BIN="$APP/Contents/MacOS/ZenPad"
OUT="$ROOT/docs/screenshots"
LIB="$(mktemp -d)/notes"
mkdir -p "$OUT"

if [ ! -x "$BIN" ]; then
  echo "Build ZenPad first (or pass the path to ZenPad.app): $BIN" >&2
  exit 1
fi

# shot <name> <demo args...>
shot() {
  local name=$1; shift
  pkill -f "ZenPad.app/Contents/MacOS/ZenPad" 2>/dev/null || true
  sleep 0.5
  rm -rf "$LIB"
  "$BIN" --demo --library "$LIB" "$@" >/dev/null 2>&1 &
  local pid=$!
  disown "$pid"
  sleep "${WAIT:-3}"
  local windows id
  windows=$(swift "$ROOT/scripts/window_ids.swift" "$pid")
  # Prefer the editor window, then any real window (skips the menu bar icon's tiny window).
  id=$(echo "$windows" | awk '$5=="ZenPad" {print $1; exit}')
  [ -z "$id" ] && id=$(echo "$windows" | awk '{split($3, s, "x"); if (s[1] > 200 && s[2] > 200) {print $1; exit}}')
  if [ -n "$id" ]; then
    screencapture -x -l "$id" "$OUT/$name.png"
    echo "  $name.png"
  else
    echo "  $name: no window found" >&2
  fi
  kill "$pid" 2>/dev/null || true
}

echo "Rendering screenshots into docs/screenshots/"
shot editor-light     --scene editor --note "Launch plan" --appearance light --size 1200x780
shot editor-dark      --scene editor --note "Morning pages" --appearance dark --size 1200x780
shot split-dark       --scene editor --note "Launch plan" --appearance dark --mode split --sidebar off --size 1280x800
shot preview-light    --scene editor --note "Reading list" --appearance light --mode preview --font rounded --size 1100x720
shot focus            --scene focus --note "Morning pages" --appearance light --sidebar off --line 5 --size 1100x720
shot quickpad         --scene quickpad --appearance light
shot quickpad-dark    --scene quickpad --appearance dark
shot templates        --scene templates --note "Launch plan" --appearance light --size 1100x720
shot settings-editor  --scene settings-editor --appearance light
shot settings-shortcuts --scene settings-shortcuts --appearance dark
shot update           --scene update --appearance light

pkill -f "ZenPad.app/Contents/MacOS/ZenPad" 2>/dev/null || true
rm -rf "$(dirname "$LIB")"
echo "Done."
