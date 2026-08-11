#!/usr/bin/env bash
# Mereoleona theme — pristine backup of current desktop state.
# Refuses to overwrite an existing pristine backup (so re-running apply is safe).
set -uo pipefail
ROOT="$HOME/.mereoleona"
BK="$ROOT/backup"
mkdir -p "$BK"

if [ -f "$BK/.backup-complete" ]; then
  echo "[backup] pristine backup already exists at $BK — keeping it untouched."
  echo "[backup] (to force a fresh backup, delete $BK/.backup-complete first)"
  exit 0
fi

echo "[backup] capturing current desktop state..."

# Master + targeted dconf dumps
dconf dump /                               > "$BK/dconf-full.ini"   2>/dev/null || true
dconf dump /org/gnome/desktop/interface/   > "$BK/interface.ini"    2>/dev/null || true
dconf dump /org/gnome/desktop/background/   > "$BK/background.ini"   2>/dev/null || true
dconf dump /org/gnome/desktop/screensaver/  > "$BK/screensaver.ini"  2>/dev/null || true
dconf dump /org/gnome/terminal/             > "$BK/terminal.ini"     2>/dev/null || true
dconf dump /org/gnome/shell/                > "$BK/shell.ini"        2>/dev/null || true

# Real wallpaper file
[ -f "$HOME/.config/background" ] && cp -f "$HOME/.config/background" "$BK/original-background" || true

# GTK CSS (record absence explicitly so restore knows to delete ours)
if [ -f "$HOME/.config/gtk-3.0/gtk.css" ]; then cp -f "$HOME/.config/gtk-3.0/gtk.css" "$BK/gtk3.css.original"; else echo absent > "$BK/gtk3.css.absent"; fi
if [ -f "$HOME/.config/gtk-4.0/gtk.css" ]; then cp -f "$HOME/.config/gtk-4.0/gtk.css" "$BK/gtk4.css.original"; else echo absent > "$BK/gtk4.css.absent"; fi

# Shell rc
[ -f "$HOME/.zshrc" ] && cp -f "$HOME/.zshrc" "$BK/zshrc.original" || true

# Human/machine-readable manifest
{
  echo "timestamp=$(date -Iseconds)"
  echo "gtk_theme=$(gsettings get org.gnome.desktop.interface gtk-theme)"
  echo "icon_theme=$(gsettings get org.gnome.desktop.interface icon-theme)"
  echo "cursor_theme=$(gsettings get org.gnome.desktop.interface cursor-theme)"
  echo "color_scheme=$(gsettings get org.gnome.desktop.interface color-scheme)"
  echo "accent_color=$(gsettings get org.gnome.desktop.interface accent-color)"
  echo "shell_theme=$(gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null || echo \"''\")"
  echo "mono_font=$(gsettings get org.gnome.desktop.interface monospace-font-name)"
  echo "ui_font=$(gsettings get org.gnome.desktop.interface font-name)"
  echo "bg_uri=$(gsettings get org.gnome.desktop.background picture-uri)"
  echo "bg_uri_dark=$(gsettings get org.gnome.desktop.background picture-uri-dark)"
  echo "term_default=$(gsettings get org.gnome.Terminal.ProfilesList default)"
  echo "term_list=$(gsettings get org.gnome.Terminal.ProfilesList list)"
  echo "enabled_extensions=$(gsettings get org.gnome.shell enabled-extensions)"
} > "$BK/manifest.env"

gnome-extensions list   > "$BK/extensions-installed.txt" 2>/dev/null || true
flatpak list --columns=application > "$BK/flatpaks-installed.txt" 2>/dev/null || true

touch "$BK/.backup-complete"
echo "[backup] done -> $BK"
