#!/usr/bin/env bash
# Generate Mereoleona wallpapers from her source image.
#   assets/mereoleona-desktop.jpg  — darkened + vignette (icons stay readable)
#   assets/mereoleona-lock.jpg     — vivid, punchy grade for lock/login
set -uo pipefail
ROOT="$HOME/.mereoleona"; A="$ROOT/assets"; mkdir -p "$A"
SRC="${1:-$HOME/Pictures/peakpx.jpg}"
[ -f "$SRC" ] || { echo "source image not found: $SRC" >&2; exit 1; }

# normalize to a 1920x1080 cover
convert "$SRC" -resize 1920x1080^ -gravity center -extent 1920x1080 "$A/_cover.png"

# vivid lock screen
convert "$A/_cover.png" -modulate 104,124,100 -brightness-contrast 2x9 "$A/mereoleona-lock.jpg"

# atmospheric desktop: darken + warm + radial vignette
convert -size 1920x1080 radial-gradient:white-'#383838' "$A/_vig.png"
convert "$A/_cover.png" -brightness-contrast -16x6 -modulate 100,112,100 "$A/_dark.png"
convert "$A/_dark.png" "$A/_vig.png" -compose multiply -composite "$A/mereoleona-desktop.jpg"

rm -f "$A/_cover.png" "$A/_vig.png" "$A/_dark.png"
echo "wallpapers -> $A/mereoleona-desktop.jpg , $A/mereoleona-lock.jpg"
