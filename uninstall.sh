#!/usr/bin/env bash
# 🔥 Mereoleona Vermillion — Uninstaller
# Reverses everything install.sh did. Run as your normal user (NOT sudo).
set -e

INSTALL_DIR="$HOME/.mereoleona"
BIN_DIR="$HOME/.local/bin"
EXT_BASE="$HOME/.local/share/gnome-shell/extensions"

c_blue='\033[1;38;2;111;168;181m'
c_grn='\033[0;32m'
c_red='\033[0;31m'
c_rst='\033[0m'

say() { printf "${c_blue}❄  %s${c_rst}\n" "$*"; }
ok()  { printf "${c_grn}✓  %s${c_rst}\n" "$*"; }
die() { printf "${c_red}✗  %s${c_rst}\n" "$*"; exit 1; }

[ "$(id -u)" = 0 ] && die "Run as your normal user, not with sudo."

echo ""
printf "${c_blue}╔══════════════════════════════════════════╗${c_rst}\n"
printf "${c_blue}║  ❄  Mereoleona Vermillion Uninstaller   ║${c_rst}\n"
printf "${c_blue}╚══════════════════════════════════════════╝${c_rst}\n"
echo ""

# 1. Restore theme if active
if [ -f "$INSTALL_DIR/state/active" ]; then
    say "Theme is active — restoring original setup first..."
    bash "$INSTALL_DIR/scripts/restore.sh" || true
fi

# 2. Disable + remove extensions
say "Disabling GNOME Shell extensions..."
for ext in mereoleona-pins@mereoleona mereoleona-spectrum@mereoleona mereoleona-launcher@mereoleona mereoleona-timer@mereoleona; do
    gnome-extensions disable "$ext" 2>/dev/null || true
    CUR="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null)"
    NEW="$(printf '%s' "$CUR" | sed "s/, '$ext'//g; s/'$ext', //g; s/'$ext'//g")"
    [ "$NEW" != "$CUR" ] && gsettings set org.gnome.shell enabled-extensions "$NEW" || true
    rm -rf "$EXT_BASE/$ext"
    ok "Removed: $ext"
done

# 3. Remove autostart entries
say "Removing autostart entries..."
rm -f "$HOME/.config/autostart/mereoleona-freeze.desktop" \
      "$HOME/.config/autostart/mereoleona-spectrum-enable.desktop" \
      "$HOME/.config/autostart/mereoleona-hidamari.desktop"
ok "Autostart entries removed."

# 4. Remove CLI tools
say "Removing CLI tools..."
for tool in mereoleona freeze fixfp mereoleona-lyrics mereoleona-viz lyrics-v2 mereo-ext mereo-ext-ui mereo-standup; do
    rm -f "$BIN_DIR/$tool"
done
ok "CLI tools removed."

# 5. Remove ~/.mereoleona (the runtime directory — backup kept)
say "Removing $INSTALL_DIR ..."
if [ -d "$INSTALL_DIR/backup" ] && [ -f "$INSTALL_DIR/backup/.backup-complete" ]; then
    echo "  Your original settings backup is preserved at: $INSTALL_DIR/backup"
    echo "  Delete it manually if you no longer need it."
fi
# Remove everything except backup (which contains the user's original settings)
find "$INSTALL_DIR" -maxdepth 1 ! -name backup ! -name . -exec rm -rf {} + 2>/dev/null || true
ok "Runtime files removed (backup kept at $INSTALL_DIR/backup)."

echo ""
ok "Mereoleona fully uninstalled."
echo "  Open a new terminal — your original prompt/colors are restored."
echo "  Log out and back in to clear window-fire animations."
echo ""
