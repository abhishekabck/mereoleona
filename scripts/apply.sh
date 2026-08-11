#!/usr/bin/env bash
# Apply the Mereoleona fire theme. Idempotent & fully reversible (see restore.sh).
set -uo pipefail
ROOT="$HOME/.mereoleona"; A="$ROOT/assets"; STATE="$ROOT/state"; BK="$ROOT/backup"
mkdir -p "$STATE"

c_ember='\033[1;38;2;232;101;14m'; c_gold='\033[1;38;2;242;168;30m'; c_rst='\033[0m'
say(){ printf "${c_ember}🔥 %s${c_rst}\n" "$*"; }
warn(){ printf "${c_gold}⚠  %s${c_rst}\n" "$*"; }

# 0) pristine backup first (no-op if already taken)
bash "$ROOT/scripts/backup.sh"
# snapshot p10k config too (we don't edit it, but keep a copy just in case)
[ -f "$HOME/.p10k.zsh" ] && [ ! -f "$BK/p10k.zsh.original" ] && cp -f "$HOME/.p10k.zsh" "$BK/p10k.zsh.original"

# 1) terminal profile -> default
say "Forging the Mereoleona terminal profile..."
UUID="$(bash "$ROOT/scripts/terminal-profile.sh" | tail -n1)"
echo "$UUID" > "$STATE/term-uuid"
gsettings set org.gnome.Terminal.ProfilesList default "'$UUID'"

# 2) GTK fire accents (gtk3 + gtk4/libadwaita)
say "Layering ember accents onto GTK..."
strip_css(){ local f="$1"; [ -f "$f" ] && grep -q 'MEREOLEONA FIRE LAYER START' "$f" && \
  sed -i '/>>> MEREOLEONA FIRE LAYER START <<</,/>>> MEREOLEONA FIRE LAYER END <<</d' "$f"; }
inject_css(){ local f="$1"; mkdir -p "$(dirname "$f")"; touch "$f"; strip_css "$f"; printf '\n' >> "$f"; cat "$ROOT/gtk/mereoleona-gtk.css" >> "$f"; }
inject_css "$HOME/.config/gtk-3.0/gtk.css"
inject_css "$HOME/.config/gtk-4.0/gtk.css"

# 3) zsh fire layer (sourced; your .zshrc body & .p10k.zsh untouched)
say "Igniting the shell..."
RC="$HOME/.zshrc"
# Prepend POWERLEVEL9K_INSTANT_PROMPT=quiet (must sit ABOVE the instant-prompt block)
# so our startup banner + p10k recolor don't trigger the instant-prompt warning.
if [ -f "$RC" ] && ! grep -q 'MEREOLEONA P10K START' "$RC" 2>/dev/null; then
  tmpf="$(mktemp)"
  printf '# >>> MEREOLEONA P10K START <<<\ntypeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet\n# >>> MEREOLEONA P10K END <<<\n\n' > "$tmpf"
  cat "$RC" >> "$tmpf" && mv "$tmpf" "$RC"
fi
if grep -q 'MEREOLEONA ZSH START' "$RC" 2>/dev/null; then
  sed -i '/# >>> MEREOLEONA ZSH START/,/# >>> MEREOLEONA ZSH END/d' "$RC"
fi
cat >> "$RC" <<'EOF'

# >>> MEREOLEONA ZSH START <<<
[ -f "$HOME/.mereoleona/shell/mereoleona.zsh" ] && source "$HOME/.mereoleona/shell/mereoleona.zsh"
# >>> MEREOLEONA ZSH END <<<
EOF

# 4) wallpaper (static fire) + lock screen
say "Setting the blaze as wallpaper..."
[ -f "$A/mereoleona-desktop.jpg" ] || bash "$ROOT/scripts/gen-wallpaper.sh" >/dev/null 2>&1 || true
if [ -f "$A/mereoleona-desktop.jpg" ]; then
  gsettings set org.gnome.desktop.background picture-uri      "file://$A/mereoleona-desktop.jpg"
  gsettings set org.gnome.desktop.background picture-uri-dark "file://$A/mereoleona-desktop.jpg"
  gsettings set org.gnome.desktop.background picture-options  "zoom"
fi
[ -f "$A/mereoleona-lock.jpg" ] && gsettings set org.gnome.desktop.screensaver picture-uri "file://$A/mereoleona-lock.jpg" || true

# 5) keep dark mode
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true

# 5b) ember-glow the space-bar workspace pills (live, no logout; original value
#     is in the backup so restore's dconf-load puts it back exactly)
if dconf read /org/gnome/shell/extensions/space-bar/appearance/application-styles >/dev/null 2>&1; then
  say "Ember-glowing the workspace pills..."
  SB='.space-bar {\n  -natural-hpadding: 12px;\n}\n\n.space-bar-workspace-label.active {\n  margin: 0 4px;\n  background-color: rgba(232,101,14,0.95);\n  color: rgba(22,12,7,1);\n  border-color: rgba(255,201,77,0.9);\n  font-weight: 700;\n  border-radius: 4px;\n  border-width: 1px;\n  padding: 3px 8px;\n}\n\n.space-bar-workspace-label.inactive {\n  margin: 0 4px;\n  background-color: rgba(0,0,0,0);\n  color: rgba(242,168,30,1);\n  border-color: rgba(0,0,0,0);\n  font-weight: 700;\n  border-radius: 4px;\n  border-width: 0px;\n  padding: 3px 8px;\n}\n\n.space-bar-workspace-label.inactive.empty {\n  margin: 0 4px;\n  background-color: rgba(0,0,0,0);\n  color: rgba(120,80,50,0.6);\n  border-color: rgba(0,0,0,0);\n  font-weight: 700;\n  border-radius: 4px;\n  border-width: 0px;\n  padding: 3px 8px;\n}'
  dconf write /org/gnome/shell/extensions/space-bar/appearance/application-styles "'$SB'" 2>/dev/null || true
fi

# 5c) ember GNOME Shell theme (top bar / menus / overview) — live via user-theme.
#     user-theme's gsettings schema isn't globally registered, so use dconf.
if [ -d "$HOME/.local/share/themes/Mereoleona-Fire/gnome-shell" ]; then
  say "Tinting the top bar & menus ember (shell theme)..."
  CUR="$(dconf read /org/gnome/shell/extensions/user-theme/name 2>/dev/null)"
  # record the real previous theme once (never record our own theme as 'previous')
  if [ ! -s "$STATE/prev-shell-theme" ] && [ "$CUR" != "'Mereoleona-Fire'" ]; then
    printf '%s' "$CUR" > "$STATE/prev-shell-theme"
  fi
  dconf write /org/gnome/shell/extensions/user-theme/name "'Mereoleona-Fire'" 2>/dev/null || true
fi

# 5d) Alt-Tab switcher is intentionally left ALONE. CoverflowAltTab renders the live
#     desktop and blur-my-shell paints its own wallpaper layer over it, so a fire tint
#     can't show through — pursuing it isn't possible. Switcher stays at your originals.

# 6) fire window effects (Burn My Windows) + top-bar now-playing (Media Controls)
say "Summoning fire window effects + top-bar now-playing..."
bash "$ROOT/scripts/install-extensions.sh" || warn "extension layer incomplete (see output above)"

# 6b) music: top-bar fire spectrum (cava) + visualizer config
say "Tuning the fire music spectrum..."
mkdir -p "$HOME/.config/cava"
if [ -f "$HOME/.config/cava/config" ] && [ ! -f "$BK/cava-config.original" ] && ! grep -q 'Mereoleona fire audio visualizer' "$HOME/.config/cava/config"; then
  cp -f "$HOME/.config/cava/config" "$BK/cava-config.original"
fi
cp -f "$ROOT/music/cava-config" "$HOME/.config/cava/config"
# install + enable the top-bar spectrum extension (local; loads after logout)
SPEC="mereoleona-spectrum@mereoleona"
cp -rf "$ROOT/extensions/$SPEC" "$HOME/.local/share/gnome-shell/extensions/" 2>/dev/null || true
CUR="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null)"
if ! printf '%s' "$CUR" | grep -q "$SPEC"; then
  if [ "$CUR" = "@as []" ] || [ "$CUR" = "[]" ]; then gsettings set org.gnome.shell enabled-extensions "['$SPEC']"
  else gsettings set org.gnome.shell enabled-extensions "$(printf '%s' "$CUR" | sed "s/]$/, '$SPEC']/")"; fi
fi
# safety-net: re-enable the spectrum a few seconds after each login (GNOME sometimes
# leaves local extensions stuck "in the list but not started")
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/mereoleona-spectrum-enable.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Mereoleona Spectrum (ensure enabled)
Exec=bash -c 'sleep 8; gnome-extensions enable $SPEC'
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

# NOTE: the window-pin / "freeze" app is intentionally NOT managed here — it's a
# standalone tool controlled by the `freeze` command, independent of theme on/off.

# frost ONLY the lyrics overlay window via blur-my-shell (whitelisted)
BSD="$HOME/.local/share/gnome-shell/extensions/blur-my-shell@aunetx/schemas"
if [ -d "$BSD" ]; then
  BAPP="org.gnome.shell.extensions.blur-my-shell.applications"
  gsettings --schemadir "$BSD" set "$BAPP" blur true            2>/dev/null || true
  gsettings --schemadir "$BSD" set "$BAPP" enable-all false      2>/dev/null || true
  gsettings --schemadir "$BSD" set "$BAPP" whitelist "['mereoleona-lyrics']" 2>/dev/null || true
  gsettings --schemadir "$BSD" set "$BAPP" sigma 30             2>/dev/null || true
  gsettings --schemadir "$BSD" set "$BAPP" brightness 0.72      2>/dev/null || true
  gsettings --schemadir "$BSD" set "$BAPP" corner-radius 16     2>/dev/null || true
  # perf: STATIC (render-once) blur for panel + overview — much lighter on Intel
  gsettings --schemadir "$BSD" set org.gnome.shell.extensions.blur-my-shell.panel    static-blur true 2>/dev/null || true
  gsettings --schemadir "$BSD" set org.gnome.shell.extensions.blur-my-shell.panel    sigma 12         2>/dev/null || true
  gsettings --schemadir "$BSD" set org.gnome.shell.extensions.blur-my-shell.overview static-blur true 2>/dev/null || true
fi

# 7) self-heal: guarantee the GTK fire layer is actually present
for gf in "$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"; do
  if ! grep -q 'MEREOLEONA FIRE LAYER START' "$gf" 2>/dev/null; then
    warn "GTK layer was missing in ${gf##*/} — re-injecting"
    mkdir -p "$(dirname "$gf")"; printf '\n' >> "$gf"; cat "$ROOT/gtk/mereoleona-gtk.css" >> "$gf"
  fi
done

touch "$STATE/active"
say "Mereoleona theme APPLIED."
printf "${c_gold}   → Log out & back in to ignite the window-fire animations.${c_rst}\n"
printf "${c_gold}   → For the LIVE video wallpaper (big download): run  mereoleona live${c_rst}\n"
