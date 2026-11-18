#!/usr/bin/env bash
# kirk-boot-check.sh -- READ-ONLY diagnosis of why the Mac's boot picker doesn't show Linux.
# Changes nothing. Mounts things read-only and unmounts them again.
#
# Run as root from the kirkus live USB:
#     bash kirk-boot-check.sh
#
# Paste the whole output back into the chat.
set -uo pipefail          # deliberately NOT -e: we want to continue through failures

ESP_GUID=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
M=$(mktemp -d)
cleanup() { umount -R "$M/esp" 2>/dev/null; umount -R "$M/root" 2>/dev/null; rmdir "$M/esp" "$M/root" "$M" 2>/dev/null; }
trap cleanup EXIT
mkdir -p "$M/esp" "$M/root"

hr()   { printf '\n==== %s ====\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo bash kirk-boot-check.sh)."; exit 1; }

hr "firmware mode"
if [ -d /sys/firmware/efi ]; then echo "booted in UEFI mode: yes"; else echo "booted in UEFI mode: NO (this is itself the problem)"; fi

hr "all disks and partitions"
lsblk -p -o NAME,SIZE,FSTYPE,LABEL,PARTTYPENAME,MOUNTPOINTS | grep -Ev 'loop|zram'

hr "partition table of each internal disk"
if have sgdisk; then
  for d in $(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}'); do
    case $d in *zram*) continue ;; esac
    echo "--- $d"
    sgdisk -p "$d" 2>&1 | sed 's/^/    /'
  done
else
  echo "sgdisk not installed; skipping (run this from the kirkus live USB, which has it)"
fi

hr "EFI System Partitions found"
ESPS=$(lsblk -lnpo NAME,PARTTYPE | awk -v g="$ESP_GUID" 'tolower($2)==g{print $1}')
if [ -z "$ESPS" ]; then
  echo "NONE FOUND. No partition is typed as an EFI System Partition (GUID ef00)."
  echo "The firmware will not look for a bootloader at all. This is the problem."
else
  echo "$ESPS"
fi

hr "contents of each EFI System Partition"
for esp in $ESPS; do
  echo "--- $esp  (filesystem: $(blkid -s TYPE -o value "$esp" 2>/dev/null || echo unknown))"
  if mount -o ro "$esp" "$M/esp" 2>/dev/null; then
    find "$M/esp" -maxdepth 3 \( -iname '*.efi' -o -iname '*.icns' -o -type d \) \
      -printf '    %y %10s  %p\n' 2>/dev/null | sed "s|$M/esp|<ESP>|"
    echo "    -- the file Apple's picker looks for:"
    if [ -f "$M/esp/EFI/BOOT/BOOTX64.EFI" ]; then
      printf '    PRESENT  %s bytes  <ESP>/EFI/BOOT/BOOTX64.EFI\n' "$(stat -c %s "$M/esp/EFI/BOOT/BOOTX64.EFI")"
    else
      echo "    MISSING  <ESP>/EFI/BOOT/BOOTX64.EFI   <-- the picker has nothing to show"
    fi
    umount "$M/esp" 2>/dev/null
  else
    echo "    could not mount (not FAT? damaged?)"
  fi
done

hr "Apple partitions still present (is macOS there?)"
if lsblk -lnpo NAME,PARTTYPENAME | grep -iE 'apple|apfs' ; then
  echo "^ macOS-related partitions exist, so you can run bless from macOS."
else
  echo "none -- macOS appears to be gone, so any fix has to come from Linux or the live USB."
fi

hr "the installed Linux system"
ROOTP=$(blkid -L archroot 2>/dev/null)
if [ -z "$ROOTP" ]; then
  echo "No partition labelled 'archroot' found. Did the install finish?"
else
  FS=$(blkid -s TYPE -o value "$ROOTP")
  echo "root partition: $ROOTP  ($FS)"
  if [ "$FS" = btrfs ]; then
    mount -o ro,subvol=@ "$ROOTP" "$M/root" 2>/dev/null || mount -o ro "$ROOTP" "$M/root" 2>/dev/null
    echo "btrfs subvolumes:"; btrfs subvolume list "$M/root" 2>/dev/null | sed 's/^/    /'
  else
    mount -o ro "$ROOTP" "$M/root" 2>/dev/null
  fi
  if mountpoint -q "$M/root"; then
    for f in /boot/vmlinuz-linux /boot/initramfs-linux.img /boot/intel-ucode.img /boot/grub/grub.cfg /etc/default/grub /etc/os-release; do
      if [ -e "$M/root$f" ]; then printf '    PRESENT  %8s  %s\n' "$(stat -c %s "$M/root$f")" "$f"
      else printf '    MISSING            %s\n' "$f"; fi
    done
    echo "    -- GRUB modules installed for:"
    ls "$M/root/boot/grub" 2>/dev/null | sed 's/^/       /'
    echo "    -- first menu entries in grub.cfg:"
    grep -n '^menuentry\|^submenu' "$M/root/boot/grub/grub.cfg" 2>/dev/null | head -5 | sed 's/^/       /'
    echo "    -- GRUB_DISTRIBUTOR line:"
    grep -n 'GRUB_DISTRIBUTOR' "$M/root/etc/default/grub" 2>/dev/null | sed 's/^/       /'
    echo "    -- fstab:"
    grep -v '^#' "$M/root/etc/fstab" 2>/dev/null | grep -v '^$' | sed 's/^/       /'
    umount -R "$M/root" 2>/dev/null
  else
    echo "    could not mount the root partition"
  fi
fi

hr "NVRAM boot entries as Linux sees them"
# Note: on Macs, WRITING NVRAM entries with efibootmgr has historically been reported to damage
# firmware. Reading is safe; this script never writes.
if have efibootmgr; then
  efibootmgr -v 2>&1 | sed 's/^/    /'
else
  echo "    efibootmgr not installed; skipping"
fi

hr "summary"
echo "Send this whole output back. The three lines that matter most:"
echo "  1. whether <ESP>/EFI/BOOT/BOOTX64.EFI is PRESENT or MISSING"
echo "  2. whether any Apple/APFS partition still exists"
echo "  3. whether /boot/grub/grub.cfg and /boot/vmlinuz-linux are PRESENT"
