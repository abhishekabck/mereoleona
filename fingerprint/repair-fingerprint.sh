#!/usr/bin/env bash
# Repair the Elan/elanmoc2 reader when it instantly fails / "already claimed" /
# "exhausted" without letting you touch the sensor (a stuck device claim after a
# fprintd crash). Or cleanly turn fingerprint off.
#
#   REPAIR  :  sudo bash ~/.mereoleona/fingerprint/repair-fingerprint.sh
#   DISABLE :  sudo bash ~/.mereoleona/fingerprint/repair-fingerprint.sh --disable
set -uo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo:  sudo bash $0 ${1:-}"; exit 1; }
USR="${SUDO_USER:-$(logname)}"
ember(){ printf '\n\033[1;38;2;232;101;14m🔥 %s\033[0m\n' "$*"; }

if [ "${1:-}" = "--disable" ]; then
  ember "Turning fingerprint OFF (PAM) so it stops interfering with sudo/login..."
  pam-auth-update --remove fprintd 2>/dev/null || true
  sed -i '/pam_fprintd\.so/d' /etc/pam.d/common-auth 2>/dev/null || true
  rm -f /etc/systemd/system/fprintd.service.d/10-mereo-recover.conf 2>/dev/null || true
  systemctl daemon-reload 2>/dev/null || true
  systemctl stop fprintd 2>/dev/null || true
  ember "Disabled. Password-only now. Re-enable later by re-running this without --disable, or 'sudo pam-auth-update'."
  exit 0
fi

ember "1/4  Releasing the stuck claim + enabling AUTO-RECOVERY (so future crashes self-heal)..."
systemctl stop fprintd 2>/dev/null || true
rm -f /var/crash/_usr_libexec_fprintd.* 2>/dev/null || true     # clear the crash + nag
# if fprintd crashes, systemd restarts it automatically -> releases the stuck claim
mkdir -p /etc/systemd/system/fprintd.service.d
cat > /etc/systemd/system/fprintd.service.d/10-mereo-recover.conf <<EOF
[Service]
Restart=on-failure
RestartSec=2
EOF
systemctl daemon-reload
sleep 1
systemctl start fprintd 2>/dev/null || true
sleep 1

ember "2/4  Re-enrolling fresh (corrupt enrol data can crash the driver)..."
sudo -u "$USR" fprintd-delete "$USR" 2>/dev/null || true
echo "     >> touch the sensor a few times when prompted <<"
if ! sudo -u "$USR" fprintd-enroll "$USR"; then
  echo "     enrol didn't finish — the driver may be crashing. Re-run, or use --disable."
fi

ember "3/4  More attempts + drop debug (so one glitch isn't instant 'exhausted')..."
sed -i -E 's/(pam_fprintd\.so[^#]*)max-tries=[0-9]+/\1max-tries=5/' /etc/pam.d/common-auth 2>/dev/null || true
sed -i -E 's/(pam_fprintd\.so.*[^ ]) # debug/\1/'                    /etc/pam.d/common-auth 2>/dev/null || true
echo "     now: $(grep pam_fprintd.so /etc/pam.d/common-auth 2>/dev/null)"

ember "4/4  Quick self-test..."
echo "     Run in a terminal:  sudo -k true     (it should now WAIT for your finger)"
ember "Done. If it still fails instantly, the elanmoc2 build is crashing on your hardware —"
echo  "      then either update the driver or run:  sudo bash $0 --disable"
