#!/usr/bin/env bash
# kirk-boot-fix.sh -- reinstall the bootloader for an already-installed Kirk Arch Linux.
#
# Run as root from the Kirk Arch Linux live USB, AFTER running kirk-boot-check.sh:
#     bash kirk-boot-fix.sh            # reinstall GRUB at the path Apple's picker scans
#     bash kirk-boot-fix.sh --refind   # also install rEFInd (needs internet in the live session)
#
# It does not touch macOS's boot files. Anything it replaces on the EFI partition is backed up
# with a .pre-kirks suffix first.
set -euo pipefail

ESP_GUID=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
WANT_REFIND=no
[ "${1:-}" = --refind ] && WANT_REFIND=yes

[ "$(id -u)" -eq 0 ] || { echo "Run as root."; exit 1; }
[ -d /sys/firmware/efi ] || { echo "Not booted in UEFI mode. Boot the USB via 'EFI Boot' (hold Option)."; exit 1; }

# ---- find the installed system ----
ROOT=$(blkid -L archroot 2>/dev/null || true)
[ -n "$ROOT" ] || { echo "No partition labelled 'archroot'. Run kirk-boot-check.sh first."; exit 1; }
FS=$(blkid -s TYPE -o value "$ROOT")

# ---- find the EFI partition on the same disk as the root ----
DISK=/dev/$(lsblk -no PKNAME "$ROOT" | head -1)
ESP=$(lsblk -lnpo NAME,PARTTYPE "$DISK" | awk -v g="$ESP_GUID" 'tolower($2)==g{print $1; exit}')
[ -n "$ESP" ] || { echo "No EFI System Partition on $DISK. Run kirk-boot-check.sh first."; exit 1; }

echo "root: $ROOT ($FS)    EFI: $ESP    disk: $DISK"
printf 'Reinstall the bootloader onto %s? [y/N] ' "$ESP"
read -r reply
case "${reply:-n}" in y|Y|yes|YES) ;; *) echo "Aborted."; exit 1 ;; esac

# ---- mount exactly as the installer does ----
umount -R /mnt 2>/dev/null || true
if [ "$FS" = btrfs ]; then
  BTRFS_OPTS=noatime,compress=zstd:1,space_cache=v2,discard=async
  mount -o "$BTRFS_OPTS,subvol=@" "$ROOT" /mnt
  mkdir -p /mnt/home /mnt/var/log /mnt/var/cache/pacman/pkg
  mount -o "$BTRFS_OPTS,subvol=@home"  "$ROOT" /mnt/home  2>/dev/null || true
  mount -o "$BTRFS_OPTS,subvol=@log"   "$ROOT" /mnt/var/log 2>/dev/null || true
  mount -o "$BTRFS_OPTS,subvol=@cache" "$ROOT" /mnt/var/cache/pacman/pkg 2>/dev/null || true
else
  mount "$ROOT" /mnt
fi
mount --mkdir "$ESP" /mnt/efi
trap 'umount -R /mnt 2>/dev/null || true' EXIT

# ---- back up whatever is at the path Apple scans ----
if [ -f /mnt/efi/EFI/BOOT/BOOTX64.EFI ] && [ ! -f /mnt/efi/EFI/BOOT/BOOTX64.EFI.pre-kirks ]; then
  cp /mnt/efi/EFI/BOOT/BOOTX64.EFI /mnt/efi/EFI/BOOT/BOOTX64.EFI.pre-kirks
  echo "backed up the existing BOOTX64.EFI as BOOTX64.EFI.pre-kirks"
fi

# ---- reinstall GRUB ----
# --removable writes to <ESP>/EFI/BOOT/BOOTX64.EFI, which is the only path Apple's firmware scans
# for a non-Apple loader. It also avoids writing NVRAM entries, which has been reported to damage
# Mac firmware.
echo "== installing GRUB =="
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi \
  --bootloader-id=KirkArch --removable --recheck

echo "== regenerating grub.cfg =="
if ! arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg; then
  echo "grub-mkconfig failed; disabling the btrfs snapshot submenu and retrying"
  [ -f /mnt/etc/grub.d/41_snapshots-btrfs ] && chmod -x /mnt/etc/grub.d/41_snapshots-btrfs
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
fi

# ---- optional: rEFInd ----
# rEFInd is the boot manager most Mac users end up on, because it copes with Apple firmware quirks
# that plain GRUB does not. It is installed IN ADDITION to GRUB and can chain-load macOS too.
if [ "$WANT_REFIND" = yes ]; then
  echo "== installing rEFInd =="
  if arch-chroot /mnt pacman -Sy --noconfirm refind; then
    # --usedefault writes to the same removable path Apple scans, replacing GRUB there.
    arch-chroot /mnt refind-install --usedefault "$ESP" --yes \
      || arch-chroot /mnt refind-install --usedefault "$ESP"
    echo "rEFInd installed. It will scan for both Linux and macOS at boot."
  else
    echo "Could not install refind (no internet in the live session?). GRUB is still installed."
  fi
fi

# ---- verify ----
echo
echo "== verification =="
if [ -f /mnt/efi/EFI/BOOT/BOOTX64.EFI ]; then
  printf 'OK   <ESP>/EFI/BOOT/BOOTX64.EFI   %s bytes\n' "$(stat -c %s /mnt/efi/EFI/BOOT/BOOTX64.EFI)"
else
  echo 'FAIL <ESP>/EFI/BOOT/BOOTX64.EFI is still missing'
fi
if [ -s /mnt/boot/grub/grub.cfg ]; then
  printf 'OK   /boot/grub/grub.cfg          %s bytes\n' "$(stat -c %s /mnt/boot/grub/grub.cfg)"
else
  echo 'FAIL /boot/grub/grub.cfg is empty or missing'
fi

sync
umount -R /mnt 2>/dev/null || true
trap - EXIT

cat <<'MSG'

Done. Now:
  1. Shut down fully (not reboot).
  2. Reset NVRAM: power on and immediately hold Cmd+Option+P+R for about 20 seconds,
     through two chimes. This clears a stale boot-picker cache, which is a common cause
     of a loader that is present but not listed.
  3. Shut down again, then power on while holding Option, and keep holding until the
     picker appears. Look for "EFI Boot".

If "EFI Boot" still does not appear but macOS is still installed, bless the loader from
macOS instead -- that sets the firmware's boot target directly:

  diskutil list                               # find the EFI partition, e.g. disk0s1
  sudo diskutil mount disk0s1                 # mounts it at /Volumes/EFI
  sudo bless --mount /Volumes/EFI --setBoot --file /Volumes/EFI/EFI/BOOT/BOOTX64.EFI
MSG
