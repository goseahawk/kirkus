#!/usr/bin/env bash
# Installer for Kirk Arch Linux. Asks a few questions, then runs kirk-install-backend.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root."; exit 1; }
ping -c1 -W3 archlinux.org >/dev/null 2>&1 || { echo "No internet. Run 'nmtui' to join Wi-Fi first."; exit 1; }

echo "This computer: $(/usr/local/bin/kirk-detect --summary)"
echo
echo "Current disks and partitions:"
lsblk -p -o NAME,SIZE,FSTYPE,LABEL,PARTTYPENAME | grep -Ev 'loop|zram' || true
echo
echo "  1) Erase an entire disk (removes everything on it, including any other system)"
echo "  2) Install in free space, keeping existing systems (shrink macOS or Windows first)"
echo "  3) Install to an existing partition (it gets FORMATTED) and reuse an existing EFI partition"
read -rp "Choose 1-3: " m
export KIRK_MODE KIRK_DISK="" KIRK_ROOT="" KIRK_ESP=""
case $m in
  1) KIRK_MODE=wipe;      read -rp "Disk to ERASE (e.g. /dev/sda): " KIRK_DISK;  target=$KIRK_DISK ;;
  2) KIRK_MODE=freespace; read -rp "Disk with free space (e.g. /dev/sda): " KIRK_DISK; target="free space on $KIRK_DISK" ;;
  3) KIRK_MODE=partition; read -rp "Partition to FORMAT for Linux (e.g. /dev/sda4): " KIRK_ROOT
                          read -rp "Existing EFI partition to reuse (e.g. /dev/sda1): " KIRK_ESP; target=$KIRK_ROOT ;;
  *) echo "Invalid choice."; exit 1 ;;
esac

read -rp "Filesystem: 1) btrfs with Timeshift snapshots (default)  2) ext4: " fs
case ${fs:-1} in 2) KIRK_FS=ext4 ;; *) KIRK_FS=btrfs ;; esac
read -rp "Installer engine: 1) archinstall (default)  2) pacstrap: " eng
case ${eng:-1} in 2) KIRK_ENGINE=pacstrap ;; *) KIRK_ENGINE=archinstall ;; esac
read -rp "Hostname [kirk-arch]: " KIRK_HOST; KIRK_HOST=${KIRK_HOST:-kirk-arch}
read -rp "Username: " KIRK_USER
read -rp "Timezone [UTC]: " KIRK_TZ; KIRK_TZ=${KIRK_TZ:-UTC}
read -rp "Locale [en_US.UTF-8]: " KIRK_LOCALE; KIRK_LOCALE=${KIRK_LOCALE:-en_US.UTF-8}
while true; do
  read -rsp "Password: " KIRK_PASSWORD; echo
  read -rsp "Confirm: " p2; echo
  [[ -n $KIRK_PASSWORD && $KIRK_PASSWORD == "$p2" ]] && break
  echo "Empty or mismatched."
done
[[ -e /usr/share/zoneinfo/$KIRK_TZ ]] || { echo "Unknown timezone."; exit 1; }
echo "!!! Installing to: $target. Data on the Linux target will be lost. !!!"
read -rp "Type 'yes' to continue: " c
[[ $c == yes ]] || { echo "Aborted."; exit 1; }
export KIRK_FS KIRK_ENGINE KIRK_HOST KIRK_USER KIRK_PASSWORD KIRK_TZ KIRK_LOCALE
exec /usr/local/bin/kirk-install-backend
