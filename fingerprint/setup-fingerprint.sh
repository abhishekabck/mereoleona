#!/usr/bin/env bash
# Mereoleona — enable the Elan 04f3:0c00 fingerprint reader on Ubuntu 24.04.
# Builds the community 'elanmoc2' libfprint driver, enrolls a finger, and turns on
# PAM so fingerprint works for login, screen unlock, sudo and admin prompts.
#
#   INSTALL :  sudo bash ~/.mereoleona/fingerprint/setup-fingerprint.sh
#   UNDO    :  sudo bash ~/.mereoleona/fingerprint/setup-fingerprint.sh --uninstall
#
# NOTE: this is a third-party driver built from source; it overrides the distro
# libfprint and is not auto-updated. Fully reversible with --uninstall.
set -uo pipefail

[ "$(id -u)" = 0 ] || { echo "Please run with sudo:  sudo bash $0"; exit 1; }
RUSER="${SUDO_USER:-$(logname 2>/dev/null || true)}"
[ -n "${RUSER:-}" ] && [ "$RUSER" != root ] || { echo "Run via 'sudo' from your normal user session, not a root login."; exit 1; }
BUILD="/opt/elanmoc2-libfprint"
ember(){ printf '\n\033[1;38;2;232;101;14m🔥 %s\033[0m\n' "$*"; }

# ---------------- uninstall ----------------
if [ "${1:-}" = "--uninstall" ]; then
  ember "Disabling fingerprint PAM..."
  pam-auth-update --remove fprintd 2>/dev/null || true
  ember "Deleting enrolled prints..."
  sudo -u "$RUSER" fprintd-delete "$RUSER" 2>/dev/null || true
  ember "Removing the built driver..."
  [ -d "$BUILD/builddir" ] && (cd "$BUILD/builddir" && ninja uninstall 2>/dev/null || true)
  rm -f /usr/local/lib/*/libfprint-2.so* /usr/local/lib/libfprint-2.so* 2>/dev/null || true
  ldconfig
  apt-get install --reinstall -y libfprint-2-2 2>/dev/null || true
  systemctl restart fprintd.service 2>/dev/null || true
  ember "Reverted to the stock fingerprint stack."
  exit 0
fi

# ---------------- install ----------------
ember "1/7  Confirming the reader is present..."
lsusb | grep -i '04f3:0c00' || { echo "Elan 04f3:0c00 not found on USB — aborting."; exit 1; }

ember "2/7  Installing build dependencies (a few minutes)..."
apt-get update
apt-get install -y git meson ninja-build build-essential pkg-config \
  libglib2.0-dev libgusb-dev libgirepository1.0-dev libpixman-1-dev \
  libnss3-dev libgudev-1.0-dev gtk-doc-tools || { echo "dependency install failed"; exit 1; }

ember "3/7  Fetching the elanmoc2 driver source..."
rm -rf "$BUILD"
if ! git clone --depth 1 -b elanmoc2 https://gitlab.freedesktop.org/depau/libfprint.git "$BUILD"; then
  git clone https://gitlab.freedesktop.org/depau/libfprint.git "$BUILD"
  ( cd "$BUILD" && git switch elanmoc2 )
fi

ember "4/7  Building the driver..."
cd "$BUILD"
meson setup builddir -Ddoc=false -Dgtk-examples=false 2>/dev/null || meson setup builddir
ninja -C builddir

ember "5/7  Installing the driver + restarting fprintd..."
ninja -C builddir install
ldconfig
systemctl restart fprintd.service || true
sleep 2

ember "Checking the reader is now claimed by fprintd..."
OUT="$(sudo -u "$RUSER" fprintd-list "$RUSER" 2>&1)"
echo "$OUT" | head -4
if echo "$OUT" | grep -qi 'No devices available'; then
  echo
  echo "⚠  The driver built but fprintd still reports no device."
  echo "   Try a full reboot, then re-run.  If it persists, tell Claude — stop here."
  exit 1
fi

ember "6/7  Enroll your fingerprint — touch the reader repeatedly when prompted."
echo "   (run again later to add more fingers: fprintd-enroll)"
sudo -u "$RUSER" fprintd-enroll "$RUSER" || { echo "enrollment was not completed — re-run later with: fprintd-enroll"; }

ember "7/7  Enabling fingerprint for login / unlock / sudo / admin prompts..."
pam-auth-update --enable fprintd 2>/dev/null || pam-auth-update

ember "DONE.  Lock your screen (Super+L) or log out to try it — you'll see"
echo    "   'Place your finger on the reader'.  sudo will accept your finger too."
echo    "   To undo everything:  sudo bash $0 --uninstall"
