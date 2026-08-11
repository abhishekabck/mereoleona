#!/usr/bin/env bash
# Restore the desktop to its pre-Mereoleona state, from the pristine backup.
set -uo pipefail
ROOT="$HOME/.mereoleona"; STATE="$ROOT/state"; BK="$ROOT/backup"

c_blue='\033[1;38;2;111;168;181m'; c_rst='\033[0m'
say(){ printf "${c_blue}❄  %s${c_rst}\n" "$*"; }

[ -f "$BK/.backup-complete" ] || { echo "No backup found at $BK — refusing to 'restore' blindly." >&2; exit 1; }

# 1) roll back all settings we touched, straight from backup dumps
say "Restoring desktop, terminal, shell & extension settings..."
[ -f "$BK/interface.ini" ]  && dconf load /org/gnome/desktop/interface/  < "$BK/interface.ini"  2>/dev/null || true
[ -f "$BK/background.ini" ] && dconf load /org/gnome/desktop/background/  < "$BK/background.ini" 2>/dev/null || true
[ -f "$BK/screensaver.ini" ]&& dconf load /org/gnome/desktop/screensaver/ < "$BK/screensaver.ini" 2>/dev/null || true
[ -f "$BK/terminal.ini" ]   && dconf load /org/gnome/terminal/             < "$BK/terminal.ini"   2>/dev/null || true
# clear keys we ADDED that weren't in the backup, then re-load original values on top
dconf reset -f /org/gnome/shell/extensions/coverflowalttab/ 2>/dev/null || true
[ -f "$BK/shell.ini" ]      && dconf load /org/gnome/shell/                < "$BK/shell.ini"      2>/dev/null || true
# force dconf to flush the loads before we return (prevents a fast on-after-off race)
dconf read /org/gnome/shell/extensions/coverflowalttab/switcher-background-color >/dev/null 2>&1 || true

# 2) remove the orphaned Mereoleona terminal profile subtree
if [ -f "$STATE/term-uuid" ]; then
  UUID="$(cat "$STATE/term-uuid")"
  dconf reset -f "/org/gnome/terminal/legacy/profiles:/:${UUID}/" 2>/dev/null || true
fi

# 3) GTK CSS — restore exactly
say "Removing GTK ember layer..."
if [ -f "$BK/gtk4.css.original" ]; then cp -f "$BK/gtk4.css.original" "$HOME/.config/gtk-4.0/gtk.css"; fi
G3="$HOME/.config/gtk-3.0/gtk.css"
if [ -f "$BK/gtk3.css.absent" ]; then
  rm -f "$G3"                                   # it didn't exist before
elif [ -f "$BK/gtk3.css.original" ]; then
  cp -f "$BK/gtk3.css.original" "$G3"
fi

# 3b) shell theme — back to whatever it was (via dconf; gsettings schema absent)
PREV="$(cat "$STATE/prev-shell-theme" 2>/dev/null)"
if [ -n "$PREV" ]; then
  dconf write /org/gnome/shell/extensions/user-theme/name "$PREV" 2>/dev/null || true
else
  dconf reset /org/gnome/shell/extensions/user-theme/name 2>/dev/null || true
fi

# 4) zsh — drop our source block
say "Cooling the shell..."
RC="$HOME/.zshrc"
[ -f "$RC" ] && grep -q 'MEREOLEONA ZSH START' "$RC" && \
  sed -i '/# >>> MEREOLEONA ZSH START/,/# >>> MEREOLEONA ZSH END/d' "$RC"
[ -f "$RC" ] && grep -q 'MEREOLEONA P10K START' "$RC" && \
  sed -i '/# >>> MEREOLEONA P10K START/,/# >>> MEREOLEONA P10K END/d' "$RC"

# 5) turn off the fire-window extension + live wallpaper
say "Extinguishing window-fire & live wallpaper..."
gnome-extensions disable burn-my-windows@schneegans.github.com 2>/dev/null || true
dconf reset -f /org/gnome/shell/extensions/burn-my-windows/ 2>/dev/null || true
# re-enable blur-my-shell's coverflow blur (back to its default) + reload it
dconf reset /org/gnome/shell/extensions/blur-my-shell/coverflow-alt-tab/blur 2>/dev/null || true
BMS_EXT="blur-my-shell@aunetx"
if gnome-extensions info "$BMS_EXT" 2>/dev/null | grep -qi 'State: ACTIVE'; then
  gnome-extensions disable "$BMS_EXT" 2>/dev/null; sleep 1; gnome-extensions enable "$BMS_EXT" 2>/dev/null
fi
# reload CoverflowAltTab so your original switcher colors re-apply live
CF_EXT="CoverflowAltTab@palatis.blogspot.com"
if gnome-extensions info "$CF_EXT" 2>/dev/null | grep -qi 'State: ACTIVE'; then
  gnome-extensions disable "$CF_EXT" 2>/dev/null; sleep 1; gnome-extensions enable "$CF_EXT" 2>/dev/null
fi
# stop & un-autostart Hidamari live wallpaper if present
flatpak kill io.github.jeffshee.Hidamari 2>/dev/null || true
rm -f "$HOME/.config/autostart/hidamari.desktop" "$HOME/.config/autostart/mereoleona-hidamari.desktop" 2>/dev/null || true

# music module: stop visualizer, drop autostart, disable Media Controls, restore cava config
pkill -f 'kitty.*mereoleona-viz' 2>/dev/null || true
pkill -f 'kitty.*mereoleona-lyrics' 2>/dev/null || true
rm -f "$HOME/.config/autostart/mereoleona-viz.desktop" 2>/dev/null || true
gnome-extensions disable mediacontrols@cliffniff.github.com 2>/dev/null || true
gnome-extensions disable mereoleona-spectrum@mereoleona 2>/dev/null || true
rm -f "$HOME/.config/autostart/mereoleona-spectrum-enable.desktop" 2>/dev/null || true
# (the window-pin / "freeze" app is left alone — it's standalone, managed by `freeze`)
# revert the static-blur perf tweak back to your original (live blur)
BSD2="$HOME/.local/share/gnome-shell/extensions/blur-my-shell@aunetx/schemas"
if [ -d "$BSD2" ]; then
  gsettings --schemadir "$BSD2" set org.gnome.shell.extensions.blur-my-shell.panel    static-blur false 2>/dev/null || true
  gsettings --schemadir "$BSD2" set org.gnome.shell.extensions.blur-my-shell.panel    sigma 16          2>/dev/null || true
  gsettings --schemadir "$BSD2" set org.gnome.shell.extensions.blur-my-shell.overview static-blur false 2>/dev/null || true
fi
if [ -f "$BK/cava-config.original" ]; then
  cp -f "$BK/cava-config.original" "$HOME/.config/cava/config"
elif grep -q 'Mereoleona fire audio visualizer' "$HOME/.config/cava/config" 2>/dev/null; then
  rm -f "$HOME/.config/cava/config"
fi
# un-frost the lyrics overlay (remove our class; disable applications blur as it was)
BSD="$HOME/.local/share/gnome-shell/extensions/blur-my-shell@aunetx/schemas"
if [ -d "$BSD" ]; then
  BAPP="org.gnome.shell.extensions.blur-my-shell.applications"
  gsettings --schemadir "$BSD" set "$BAPP" whitelist "[]" 2>/dev/null || true
  gsettings --schemadir "$BSD" set "$BAPP" blur false     2>/dev/null || true
fi

rm -f "$STATE/active"
say "Restored to your MacTahoe-Dark setup. (Open a new terminal for the original prompt; log out to clear window-fire.)"
