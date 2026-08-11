#!/usr/bin/env bash
# Install + enable the Mereoleona GNOME extensions (no sudo). They load after the
# next logout on Wayland.
#   - Burn My Windows  : fire on window open/close
#   - Media Controls   : now-playing (title/art/controls) in the top bar
set -uo pipefail
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
SHELL_VER="$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1)"; SHELL_VER="${SHELL_VER:-46}"

install_ext() {  # <uuid>
  local UUID="$1"
  if gnome-extensions list 2>/dev/null | grep -q "$UUID" || [ -d "$EXT_DIR/$UUID" ]; then
    echo "[$UUID] already installed"; return 0
  fi
  echo "[$UUID] fetching for GNOME $SHELL_VER ..."
  local INFO DL TMP
  INFO="$(curl -fsSL --max-time 20 "https://extensions.gnome.org/extension-info/?uuid=${UUID}&shell_version=${SHELL_VER}" 2>/dev/null)" \
    || { echo "[$UUID] no network — skipping"; return 0; }
  DL="$(printf '%s' "$INFO" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("download_url",""))
except Exception: print("")' 2>/dev/null)"
  [ -n "$DL" ] || { echo "[$UUID] no build for shell $SHELL_VER — skipping"; return 0; }
  TMP="$(mktemp -d)"
  if curl -fsSL --max-time 60 "https://extensions.gnome.org${DL}" -o "$TMP/e.zip"; then
    gnome-extensions install --force "$TMP/e.zip" && echo "[$UUID] installed"
  else
    echo "[$UUID] download failed"
  fi
  rm -rf "$TMP"
}

enable_ext() {  # <uuid>
  local UUID="$1"
  gnome-extensions enable "$UUID" 2>/dev/null || true
  local CUR; CUR="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null)"
  if ! printf '%s' "$CUR" | grep -q "$UUID"; then
    if [ "$CUR" = "@as []" ] || [ "$CUR" = "[]" ]; then gsettings set org.gnome.shell enabled-extensions "['$UUID']"
    else gsettings set org.gnome.shell enabled-extensions "$(printf '%s' "$CUR" | sed "s/]$/, '$UUID']/")"; fi
  fi
}

BMW="burn-my-windows@schneegans.github.com"
MC="mediacontrols@cliffniff.github.com"

install_ext "$BMW"; enable_ext "$BMW"
install_ext "$MC";  enable_ext "$MC"

# Burn My Windows — Mereoleona fire profile (Fire is its default effect anyway)
PD="$HOME/.config/burn-my-windows/profiles"; mkdir -p "$PD"
# light + correctly-keyed for BMW v48 (fire-scale / fire-movement-speed / fire-color-1..5);
# fire-3d-noise=false is the big GPU win that cuts startup lag on integrated graphics.
cat > "$PD/mereoleona.conf" <<'EOF'
[burn-my-windows-profile]
fire-enable-effect=true
fire-animation-time=450
fire-movement-speed=1.5
fire-scale=0.75
fire-3d-noise=false
fire-color-1=rgba(140,31,22,0.55)
fire-color-2=rgba(200,52,30,0.85)
fire-color-3=rgba(232,101,14,0.95)
fire-color-4=rgba(242,168,30,1.0)
fire-color-5=rgba(255,246,230,1.0)
EOF

# Media Controls — fire-friendly: scrolling title, colored icon, controls
MC_SD="$EXT_DIR/$MC/schemas"; MC_SCH="org.gnome.shell.extensions.mediacontrols"
if [ -d "$MC_SD" ]; then
  mc(){ gsettings --schemadir "$MC_SD" set "$MC_SCH" "$1" "$2" 2>/dev/null || true; }
  mc scroll-labels true
  mc scroll-speed 5
  mc fixed-label-width true        # title scrolls in a fixed box; never overlaps the right side
  mc label-width 200
  mc show-label true
  mc show-control-icons true
  mc show-player-icon true
  mc colored-player-icon true
  mc show-track-slider false
  mc extension-position 'Left'     # left cluster, near the spectrum — keeps the right side clear
  mc extension-index 2
fi
echo "[extensions] done (activate after logout)"
