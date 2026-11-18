#!/usr/bin/env bash
# Builds the kirkus ISO. Run on an Arch Linux system (or Arch container/VM) with internet access.
# On a non-Arch host, run ./build-docker.sh instead.
set -euo pipefail
# KIRK_VERSION overrides the version (normally today's date); passed through sudo explicitly,
# because sudo drops the caller's environment.
[[ $EUID -eq 0 ]] || exec sudo KIRK_VERSION="${KIRK_VERSION:-}" "$0" "$@"

BRAND="kirkus"
# Version = the build date as YY.MM.DD, e.g. "kirkus 26.11.18".
VERSION=${KIRK_VERSION:-$(date +%y.%m.%d)}
[[ $VERSION =~ ^[0-9]{2}\.[0-9]{2}\.[0-9]{2}$ ]] || { echo "Bad version '$VERSION': use YY.MM.DD, e.g. 26.11.18"; exit 1; }
echo "Building $BRAND $VERSION"
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$HERE/build
P=$WORK/profile

command -v mkarchiso >/dev/null || pacman -S --needed --noconfirm archiso

rm -rf "$WORK"; mkdir -p "$WORK"
cp -r /usr/share/archiso/configs/releng "$P"

# ---- Branding: ISO metadata ----
sed -i \
  -e 's|^iso_name=.*|iso_name="kirkus"|' \
  -e 's|^iso_label=.*|iso_label="KIRKUS"|' \
  -e "s|^iso_publisher=.*|iso_publisher=\"${BRAND}\"|" \
  -e "s|^iso_application=.*|iso_application=\"${BRAND} ${VERSION} Installer\"|" \
  -e "s|^iso_version=.*|iso_version=\"${VERSION}\"|" \
  "$P/profiledef.sh"

# ---- Branding: boot menu titles (UEFI + BIOS menus) ----
grep -rl 'Arch Linux' "$P/efiboot" "$P/grub" "$P/syslinux" 2>/dev/null | while read -r f; do
  sed -i "s|Arch Linux|${BRAND} ${VERSION}|g" "$f"
done

# ---- Packages for the live environment ----
# The prebuilt 'broadcom-wl' package no longer exists in the Arch repos; only the DKMS version does
# (it Replaces/Conflicts broadcom-wl). Drop any stale entry from the releng list first.
sed -i '/^broadcom-wl$/d' "$P/packages.x86_64"
# linux-headers + dkms are needed so broadcom-wl-dkms can build the 'wl' module into the ISO.
for pkg in networkmanager wpa_supplicant broadcom-wl-dkms dkms linux-headers gptfdisk dosfstools \
           e2fsprogs btrfs-progs arch-install-scripts archinstall parted; do
  grep -qx "$pkg" "$P/packages.x86_64" || echo "$pkg" >> "$P/packages.x86_64"
done

# iwd does not work with the Broadcom wl driver, so use NetworkManager + wpa_supplicant instead
find "$P/airootfs/etc/systemd/system" \( -name 'iwd.service' -o -name 'systemd-networkd.service' \
  -o -name 'systemd-networkd.socket' -o -name 'systemd-networkd-wait-online.service' \) -print -delete || true
mkdir -p "$P/airootfs/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/NetworkManager.service \
  "$P/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"

# ---- Overlays ----
cp -a "$HERE/overlay/airootfs/." "$P/airootfs/"
# the version, for the live welcome message and for the installer to pass on
echo "$VERSION" > "$P/airootfs/etc/kirk-version"
sed -i "s|@VERSION@|$VERSION|" "$P/airootfs/etc/motd"
# Files destined for the INSTALLED system ride along in /root/kirk-overlay (always installed) and
# /root/kirk-hardware (installed only when kirk-detect finds that hardware)
mkdir -p "$P/airootfs/root/kirk-overlay" "$P/airootfs/root/kirk-hardware"
cp -a "$HERE/overlay/installed/." "$P/airootfs/root/kirk-overlay/"
cp -a "$HERE/overlay/hardware/." "$P/airootfs/root/kirk-hardware/"
# The live session detects hardware too: it switches to the Broadcom wl Wi-Fi driver only on
# computers that need it, instead of blacklisting the standard drivers for everyone.
install -Dm755 "$HERE/overlay/installed/usr/local/bin/kirk-detect" "$P/airootfs/usr/local/bin/kirk-detect"
install -Dm644 "$HERE/overlay/hardware/broadcom-wl/etc/modprobe.d/broadcom-wl.conf" \
  "$P/airootfs/usr/share/kirkus/broadcom-wl-blacklist.conf"
ln -sf /etc/systemd/system/kirk-live-wifi.service \
  "$P/airootfs/etc/systemd/system/multi-user.target.wants/kirk-live-wifi.service"

cat >> "$P/profiledef.sh" <<'PERMS'

file_permissions+=(
  ["/root/install.sh"]="0:0:755"
  ["/usr/local/bin/kirk-install-backend"]="0:0:755"
  ["/usr/local/bin/kirk-detect"]="0:0:755"
  ["/usr/local/bin/kirk-live-wifi"]="0:0:755"
)
PERMS

mkarchiso -v -w "$WORK/work" -o "$HERE/out" "$P"

# Did DKMS actually build the Wi-Fi module into the live image?
if find "$WORK/work" -name 'wl.ko*' 2>/dev/null | grep -q .; then
  echo "OK: wl (Broadcom Wi-Fi) module is present in the ISO."
else
  echo "WARNING: no wl.ko found in the ISO's filesystem. DKMS probably failed to build in the build chroot."
  echo "         Scroll up for 'dkms' errors. The ISO will still boot, but Wi-Fi won't work in the live"
  echo "         session (use USB Ethernet or phone tethering to install; the installed system builds wl itself)."
fi

echo
echo "Done. ISO is in $HERE/out/"
echo "Write it with:  sudo dd if=out/kirkus-*.iso of=/dev/sdX bs=4M status=progress oflag=sync"
