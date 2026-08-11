#!/usr/bin/env bash
# ============================================================
# 🔥 Mereoleona Vermillion — Installer
# Installs the full fire theme on any Ubuntu/GNOME system.
# Run as your normal user (NOT sudo):  bash install.sh
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.mereoleona"
BIN_DIR="$HOME/.local/bin"

c_ember='\033[1;38;2;232;101;14m'
c_gold='\033[1;38;2;242;168;30m'
c_blue='\033[1;38;2;111;168;181m'
c_grn='\033[0;32m'
c_red='\033[0;31m'
c_rst='\033[0m'

say()  { printf "${c_ember}🔥 %s${c_rst}\n" "$*"; }
ok()   { printf "${c_grn}✓  %s${c_rst}\n" "$*"; }
warn() { printf "${c_gold}⚠  %s${c_rst}\n" "$*"; }
die()  { printf "${c_red}✗  %s${c_rst}\n" "$*"; exit 1; }

echo ""
printf "${c_ember}╔══════════════════════════════════════════╗${c_rst}\n"
printf "${c_ember}║   🔥  Mereoleona Vermillion Installer   ║${c_rst}\n"
printf "${c_ember}╚══════════════════════════════════════════╝${c_rst}\n"
echo ""

# ── 1. Guard: must NOT be root ────────────────────────────────────────────────
[ "$(id -u)" = 0 ] && die "Run as your normal user, not with sudo."

# ── 2. OS check ───────────────────────────────────────────────────────────────
if ! grep -qi ubuntu /etc/os-release 2>/dev/null; then
    warn "This was built for Ubuntu/GNOME. On other distros some steps may vary."
fi

# ── 3. Dependency check + optional install ────────────────────────────────────
say "Checking dependencies..."
MISSING=()
command -v gsettings        &>/dev/null || MISSING+=("libglib2.0-bin")
command -v gnome-extensions &>/dev/null || MISSING+=("gnome-shell-extensions")
command -v dconf            &>/dev/null || MISSING+=("dconf-cli")
command -v python3          &>/dev/null || MISSING+=("python3")
command -v curl             &>/dev/null || MISSING+=("curl")

if [ ${#MISSING[@]} -gt 0 ]; then
    warn "Missing packages: ${MISSING[*]}"
    read -r -p "Install them now with apt? [Y/n]: " yn
    case "${yn:-Y}" in [Nn]*) die "Install them manually, then re-run.";; esac
    sudo apt-get update -qq
    sudo apt-get install -y "${MISSING[@]}"
fi
ok "Dependencies satisfied."

# ── 4. Copy core files to ~/.mereoleona ───────────────────────────────────────
say "Installing to $INSTALL_DIR ..."
DIRS=(bin extensions gtk music perf fingerprint scripts shell assets)
for d in "${DIRS[@]}"; do
    mkdir -p "$INSTALL_DIR/$d"
    # rsync-style copy: overwrite files, skip backup/ and state/ (machine-specific)
    cp -rf "$SCRIPT_DIR/$d/." "$INSTALL_DIR/$d/"
done
# Create required runtime dirs
mkdir -p "$INSTALL_DIR/state" "$INSTALL_DIR/backup"
ok "Core files installed."

# ── 5. Install CLI tools to ~/.local/bin ──────────────────────────────────────
say "Linking CLI tools..."
mkdir -p "$BIN_DIR"
for tool in mereoleona freeze fixfp mereoleona-lyrics mereoleona-viz; do
    cp -f "$INSTALL_DIR/bin/$tool" "$BIN_DIR/$tool"
    chmod +x "$BIN_DIR/$tool"
done
ok "CLI tools installed: mereoleona, freeze, fixfp, mereoleona-lyrics, mereoleona-viz"

# ── 6. Ensure ~/.local/bin is in PATH ─────────────────────────────────────────
SHELL_RC=""
case "$SHELL" in
  */zsh)  SHELL_RC="$HOME/.zshrc" ;;
  */bash) SHELL_RC="$HOME/.bashrc" ;;
esac

if [ -n "$SHELL_RC" ] && ! grep -q 'HOME/.local/bin' "$SHELL_RC" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    ok "Added ~/.local/bin to PATH in $SHELL_RC"
fi
export PATH="$BIN_DIR:$PATH"

# ── 7. Install GNOME Shell extensions ─────────────────────────────────────────
say "Installing GNOME Shell extensions..."
EXT_BASE="$HOME/.local/share/gnome-shell/extensions"
for ext in mereoleona-pins@mereoleona mereoleona-spectrum@mereoleona; do
    mkdir -p "$EXT_BASE/$ext"
    cp -rf "$INSTALL_DIR/extensions/$ext/." "$EXT_BASE/$ext/"
    ok "Extension installed: $ext"
done

# ── 8. Enable extensions in GNOME ─────────────────────────────────────────────
say "Enabling extensions..."
_add_ext() {
    local UUID="$1"
    local CUR; CUR="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null)"
    printf '%s' "$CUR" | grep -q "$UUID" && return
    if [ "$CUR" = "@as []" ] || [ "$CUR" = "[]" ]; then
        gsettings set org.gnome.shell enabled-extensions "['$UUID']"
    else
        gsettings set org.gnome.shell enabled-extensions \
            "$(printf '%s' "$CUR" | sed "s/]$/, '$UUID']/")"
    fi
    gnome-extensions enable "$UUID" 2>/dev/null || true
}
_add_ext "mereoleona-pins@mereoleona"
_add_ext "mereoleona-spectrum@mereoleona"
ok "Extensions registered."

# ── 9. Summary ────────────────────────────────────────────────────────────────
echo ""
printf "${c_gold}══════════════════════════════════════════════${c_rst}\n"
printf "${c_grn}  Installation complete!${c_rst}\n"
printf "${c_gold}══════════════════════════════════════════════${c_rst}\n"
echo ""
echo "  Open a NEW terminal, then run:"
echo ""
printf "    ${c_ember}mereoleona on${c_rst}     — apply the fire theme\n"
printf "    ${c_ember}mereoleona status${c_rst} — check state\n"
printf "    ${c_ember}mereoleona off${c_rst}    — restore your original setup\n"
printf "    ${c_ember}freeze on${c_rst}         — enable window-pin dashboard (❄ top bar)\n"
printf "    ${c_ember}fixfp${c_rst}             — fix fingerprint reader if stuck\n"
echo ""
printf "  ${c_blue}Log out and back in once${c_rst} to activate fire window animations.\n"
echo ""
printf "  Optional apt extras (blur-bonsai/matrix effects):\n"
echo "    sudo apt install -y cava playerctl kitty fastfetch cmatrix cbonsai"
echo ""
