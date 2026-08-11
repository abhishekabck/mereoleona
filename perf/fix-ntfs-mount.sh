#!/usr/bin/env bash
# Make an NTFS drive (e.g. /mnt/d) owned by YOU, now and on every boot.
# Fixes "permission denied" when opening files on a root-mounted NTFS drive.
#
#   1) cd ~            # step OUT of the drive first!
#   2) sudo bash ~/.mereoleona/perf/fix-ntfs-mount.sh /mnt/d
#
set -uo pipefail
cd /                                   # don't hold the mount ourselves
[ "$(id -u)" = 0 ] || { echo "Run with sudo:  sudo bash $0 ${1:-/mnt/d}"; exit 1; }
MP="${1:-/mnt/d}"
USR="${SUDO_USER:-$(logname)}"
U=$(id -u "$USR"); G=$(id -g "$USR")
ember(){ printf '\n\033[1;38;2;232;101;14m🔥 %s\033[0m\n' "$*"; }

SRC=$(findmnt -n -o SOURCE --target "$MP" 2>/dev/null | head -1)
if [ -z "$SRC" ]; then
  echo "✗ $MP is not mounted. NTFS partitions available:"
  lsblk -o NAME,FSTYPE,LABEL,SIZE,UUID,MOUNTPOINTS | grep -i ntfs
  echo "Mount it (sudo mount /dev/nvme0n1pX $MP) then re-run."
  exit 1
fi
UUID=$(blkid -s UUID -o value "$SRC")
OPTS="uid=$U,gid=$G,umask=022,windows_names"
ember "Drive $SRC  UUID=$UUID  →  owner $USR ($U:$G)"

# 1) make it permanent FIRST (so even if live remount can't happen, a reboot fixes it)
ember "Writing /etc/fstab entry..."
cp /etc/fstab /etc/fstab.mereo-bak 2>/dev/null || true
sed -i "\# $MP #d" /etc/fstab 2>/dev/null || true        # remove any old line for this mountpoint
echo "UUID=$UUID $MP ntfs-3g $OPTS,nofail 0 0" >> /etc/fstab
echo "  added: UUID=$UUID $MP ntfs-3g $OPTS,nofail 0 0"

# 2) try to apply it live (needs nothing using the drive)
ember "Applying now..."
if umount "$MP" 2>/dev/null; then
  mount "$MP" && ember "DONE live ✓  — $MP is now yours."
else
  ember "Couldn't remount live (something is still using $MP — likely a terminal/app sitting inside it)."
  echo  "It's saved in fstab though, so just:  close anything using $MP  →  'sudo mount -o remount $MP'  OR simply reboot."
fi
ls -ld "$MP" 2>/dev/null; ls -la "$MP" 2>/dev/null | head -4
