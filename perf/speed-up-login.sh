#!/usr/bin/env bash
# Mereoleona — login / boot speed-ups for Ubuntu (safe, reversible).
#   APPLY :  sudo bash ~/.mereoleona/perf/speed-up-login.sh
#   UNDO  :  sudo bash ~/.mereoleona/perf/speed-up-login.sh --undo
set -uo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo:  sudo bash $0"; exit 1; }
ember(){ printf '\n\033[1;38;2;232;101;14m🔥 %s\033[0m\n' "$*"; }

if [ "${1:-}" = "--undo" ]; then
  systemctl unmask NetworkManager-wait-online.service 2>/dev/null || true
  systemctl enable NetworkManager-wait-online.service 2>/dev/null || true
  rm -f /etc/systemd/system/apt-daily.service.d/10-mereo-nice.conf \
        /etc/systemd/system/apt-daily-upgrade.service.d/10-mereo-nice.conf 2>/dev/null || true
  systemctl daemon-reload
  ember "Reverted boot tweaks. (PAM fingerprint setting left as-is.)"
  exit 0
fi

ember "1/3  Stop NetworkManager-wait-online from blocking the login screen (~5s/boot)..."
systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
systemctl mask    NetworkManager-wait-online.service 2>/dev/null || true

ember "2/3  Make background auto-updates low-priority (keeps security, kills the post-login lag)..."
for u in apt-daily apt-daily-upgrade; do
  mkdir -p "/etc/systemd/system/$u.service.d"
  cat > "/etc/systemd/system/$u.service.d/10-mereo-nice.conf" <<EOF
[Service]
Nice=19
IOSchedulingClass=idle
CPUSchedulingPolicy=idle
EOF
done
systemctl daemon-reload

ember "3/3  Make the fingerprint more reliable (3 read attempts instead of 1, drop debug)..."
if grep -q 'pam_fprintd.so' /etc/pam.d/common-auth; then
  cp /etc/pam.d/common-auth /etc/pam.d/common-auth.mereo-bak
  sed -i -E 's/(pam_fprintd\.so[^#]*)max-tries=[0-9]+/\1max-tries=3/' /etc/pam.d/common-auth
  sed -i -E 's/(pam_fprintd\.so.*[^ ]) # debug/\1/'                    /etc/pam.d/common-auth
  echo "   now: $(grep pam_fprintd.so /etc/pam.d/common-auth)"
fi

ember "DONE — reboot to feel it.   Undo:  sudo bash $0 --undo"
