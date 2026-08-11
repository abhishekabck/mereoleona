#!/usr/bin/env bash
# Render a seamless "breathing fire" loop from the desktop wallpaper using ffmpeg.
# Slow sine zoom + brightness flicker + saturation/hue pulse = living ember glow.
set -uo pipefail
ROOT="$HOME/.mereoleona"; A="$ROOT/assets"
SRC="$A/mereoleona-desktop.jpg"
[ -f "$SRC" ] || bash "$ROOT/scripts/gen-wallpaper.sh" >/dev/null 2>&1
OUT="$A/mereoleona-live.mp4"
FPS=30; DUR=12; FRAMES=$((FPS*DUR))   # 360 frames -> integer cycles = seamless loop

echo "[live] rendering ${DUR}s loop (this takes ~10-40s)..."
VF="scale=2112:1188:flags=lanczos,setsar=1,zoompan=z='1.0+0.05*(1-cos(2*PI*on/${FRAMES}))':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1920x1080:fps=${FPS},eq=brightness='0.020*sin(2*PI*n/90)':saturation='1.0+0.07*sin(2*PI*n/120)':contrast='1.0+0.03*sin(2*PI*n/72)':eval=frame,hue=h='2*sin(2*PI*n/180)'"
ffmpeg -y -loop 1 -i "$SRC" -t "$DUR" -r "$FPS" -vf "$VF" \
  -an -c:v libx264 -pix_fmt yuv420p -profile:v high -crf 20 -movflags +faststart "$OUT" \
  2>"$A/_ffmpeg.log" \
  && { echo "[live] -> $OUT"; mkdir -p "$HOME/Videos"; cp -f "$OUT" "$HOME/Videos/mereoleona-live.mp4" 2>/dev/null || true; } \
  || { echo "[live] ffmpeg failed — last lines:"; tail -n 6 "$A/_ffmpeg.log"; exit 1; }
