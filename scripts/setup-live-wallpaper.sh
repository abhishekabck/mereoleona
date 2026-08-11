#!/usr/bin/env bash
# Optional MAX-VIBE layer: live video wallpaper via Hidamari (flatpak, no sudo).
# Pulls the GNOME flatpak runtime the first time (large download).
set -uo pipefail
ROOT="$HOME/.mereoleona"; A="$ROOT/assets"
c='\033[1;38;2;232;101;14m'; r='\033[0m'; say(){ printf "${c}🔥 %s${r}\n" "$*"; }

# 1) ensure the loop video exists
[ -f "$A/mereoleona-live.mp4" ] || bash "$ROOT/scripts/gen-animated.sh"
mkdir -p "$HOME/Videos"; cp -f "$A/mereoleona-live.mp4" "$HOME/Videos/mereoleona-live.mp4" 2>/dev/null || true

# 2) flathub + Hidamari (user scope)
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
if ! flatpak info io.github.jeffshee.Hidamari >/dev/null 2>&1; then
  say "Installing Hidamari (downloads the GNOME runtime — large, please be patient)..."
  flatpak install --user -y flathub io.github.jeffshee.Hidamari \
    || { echo "Hidamari install failed (network/space?). Your static fire wallpaper is still active."; exit 1; }
fi

# 3) best-effort pre-seed config (schema/keys vary by version) + autostart
flatpak run --command=sh io.github.jeffshee.Hidamari -c \
  'gsettings set io.github.jeffshee.Hidamari data-source "file://'"$HOME"'/Videos/mereoleona-live.mp4" 2>/dev/null;
   gsettings set io.github.jeffshee.Hidamari mode 1 2>/dev/null' 2>/dev/null || true

mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/mereoleona-hidamari.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Mereoleona Live Wallpaper
Exec=flatpak run io.github.jeffshee.Hidamari -b
X-GNOME-Autostart-enabled=true
EOF

say "Hidamari ready. It will open now — if it doesn't auto-pick the video:"
echo "   → in Hidamari, choose 'mereoleona-live' (in your Videos folder) and click Apply."
echo "   → it auto-starts on future logins; 'mereoleona off' stops & un-autostarts it."
flatpak run io.github.jeffshee.Hidamari >/dev/null 2>&1 &
