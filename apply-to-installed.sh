#!/usr/bin/env bash
# Brings an ALREADY-INSTALLED system up to date with this project, without reinstalling:
#   - renames it to "kirkus YY.MM.DD" (os-release, login banner, GRUB menu, snapshot
#     submenu); the version is today's date, or set KIRK_VERSION=26.11.18 to choose it
#   - new logo and wallpaper
#   - the About This Computer page
#   - the kirkus boot splash (Plymouth), and the same look as the GRUB menu background
#   - a matching login screen and Plasma startup splash
#   - hardware support by detection: Mac fixes on Macs, the Broadcom wl Wi-Fi driver where the chip
#     needs it (and renames the files earlier versions installed for these)
#
# Run from inside the extracted project folder, on the installed system:
#     sudo ./apply-to-installed.sh
#
# It never touches the EFI partition or reinstalls GRUB, so the way your computer currently boots
# (on a Mac, the boot target you set with bless) stays exactly as it is.
set -euo pipefail
[[ $EUID -eq 0 ]] || exec sudo KIRK_VERSION="${KIRK_VERSION:-}" "$0" "$@"

VERSION=${KIRK_VERSION:-$(date +%y.%m.%d)}
[[ $VERSION =~ ^[0-9]{2}\.[0-9]{2}\.[0-9]{2}$ ]] || { echo "Bad version '$VERSION': use YY.MM.DD, e.g. 26.11.18"; exit 1; }
BRAND="kirkus $VERSION"
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$HERE/overlay/installed
[[ -d $SRC ]] || { echo "Run this from inside the project folder."; exit 1; }

echo "== packages =="
pacman -S --needed --noconfirm kinfocenter plymouth fastfetch discover flatpak
# Flathub, so Discover can install and update Flatpak apps
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
  || echo "Could not add Flathub (offline?). Run this script again later to add it."

echo "== scripts, config, icons =="
install -Dm755 -t /usr/local/bin \
  "$SRC"/usr/local/bin/kirk-about \
  "$SRC"/usr/local/bin/kirk-about-model \
  "$SRC"/usr/local/bin/kirk-about-battery \
  "$SRC"/usr/local/bin/kirk-about-storage \
  "$SRC"/usr/local/bin/kirk-about-installed \
  "$SRC"/usr/local/bin/kirk-branding \
  "$SRC"/usr/local/bin/kirk-set-wallpaper \
  "$SRC"/usr/local/bin/kirk-grub-theme-font \
  "$SRC"/usr/local/bin/kirk-login-theme \
  "$SRC"/usr/local/bin/kirk-login-preview \
  "$SRC"/usr/local/bin/kirk-install-fonts
install -Dm644 "$SRC"/etc/xdg/kcm-about-distrorc                 /etc/xdg/kcm-about-distrorc
install -Dm644 "$SRC"/etc/pacman.d/hooks/kirk-branding.hook       /etc/pacman.d/hooks/kirk-branding.hook
install -Dm644 "$SRC"/etc/xdg/autostart/kirk-wallpaper.desktop    /etc/xdg/autostart/kirk-wallpaper.desktop
install -Dm644 "$SRC"/usr/share/applications/kirk-about.desktop   /usr/share/applications/kirk-about.desktop
install -Dm644 "$SRC"/usr/share/icons/hicolor/scalable/apps/kirkus-logo.svg \
  /usr/share/icons/hicolor/scalable/apps/kirkus-logo.svg
install -Dm644 "$SRC"/usr/share/backgrounds/kirkus.svg         /usr/share/backgrounds/kirkus.svg
install -Dm644 -t /usr/share/plymouth/themes/kirkus "$SRC"/usr/share/plymouth/themes/kirkus/*
# images from earlier designs (progress bar, triangle logo, separate name/label)
rm -f /usr/share/plymouth/themes/kirkus/{track,fill,logo,title}.png
install -Dm644 -t /boot/grub/themes/kirkus "$SRC"/boot/grub/themes/kirkus/*
install -Dm755 "$SRC"/etc/grub.d/06_kirk_splash /etc/grub.d/06_kirk_splash
install -Dm644 -t /usr/share/sddm/themes/kirkus "$SRC"/usr/share/sddm/themes/kirkus/*
rm -f /usr/share/sddm/themes/kirkus/{logo,title}.png
# Space Grotesk was installed under the old name; move it rather than downloading it again
if [[ -d /usr/share/fonts/kirk-arch && ! -e /usr/share/fonts/kirkus ]]; then
  mv /usr/share/fonts/kirk-arch /usr/share/fonts/kirkus && fc-cache -f >/dev/null 2>&1 || true
fi
if [[ -d /usr/share/licenses/kirk-arch-fonts && ! -e /usr/share/licenses/kirkus-fonts ]]; then
  mv /usr/share/licenses/kirk-arch-fonts /usr/share/licenses/kirkus-fonts
fi
/usr/local/bin/kirk-install-fonts
/usr/local/bin/kirk-login-theme kirkus
# the login theme setting under its old file name would be read too; the new file replaces it
rm -f /etc/sddm.conf.d/00-kirk-arch.conf
# Plasma startup splash: install the package, make it the default for every account...
rm -rf /usr/share/plasma/look-and-feel/org.kirkus.splash
mkdir -p /usr/share/plasma/look-and-feel
cp -r "$SRC"/usr/share/plasma/look-and-feel/org.kirkus.splash /usr/share/plasma/look-and-feel/
chmod -R u=rwX,go=rX /usr/share/plasma/look-and-feel/org.kirkus.splash
install -Dm644 "$SRC"/etc/xdg/ksplashrc /etc/xdg/ksplashrc
# fastfetch: the K mark as its logo, brand colours on the labels
install -Dm644 "$SRC"/usr/share/kirkus/fastfetch-logo.txt /usr/share/kirkus/fastfetch-logo.txt
install -Dm644 "$SRC"/etc/xdg/fastfetch/config.jsonc /etc/xdg/fastfetch/config.jsonc
install -Dm644 "$SRC"/usr/share/fastfetch/presets/kirkus.jsonc /usr/share/fastfetch/presets/kirkus.jsonc
# ...and for yours too, since a splash you picked before would otherwise take precedence
if [[ -n ${SUDO_USER:-} ]] && command -v kwriteconfig6 >/dev/null; then
  sudo -H -u "$SUDO_USER" kwriteconfig6 --file ksplashrc --group KSplash --key Engine KSplashQML || true
  sudo -H -u "$SUDO_USER" kwriteconfig6 --file ksplashrc --group KSplash --key Theme org.kirkus.splash || true
fi

# Old names from earlier builds (Kirk's Arch Linux, then Kirk Arch Linux). Your desktop may still
# point at an old wallpaper path, so those paths become links to the new image rather than
# disappearing out from under Plasma. The old boot splash and GRUB theme are removed further down,
# only once the new ones are in use.
rm -f /usr/share/icons/hicolor/scalable/apps/kirks-arch-logo.svg \
      /usr/share/icons/hicolor/scalable/apps/kirk-arch-logo.svg
for old in kirks-arch kirk-arch; do
  if [[ -e /usr/share/backgrounds/$old.svg || -L /usr/share/backgrounds/$old.svg ]]; then
    ln -sfn kirkus.svg /usr/share/backgrounds/$old.svg
  fi
done
rm -rf /usr/share/plasma/look-and-feel/org.kirkarch.splash /usr/share/sddm/themes/kirk-arch \
       /usr/share/kirk-arch
rm -f /usr/share/fastfetch/presets/kirk-arch.jsonc
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true

# Install date for systems that predate /etc/kirk-release: the first pacman log entry.
if [[ ! -f /etc/kirk-release ]]; then
  d=$(grep -m1 -o '^\[[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' /var/log/pacman.log 2>/dev/null | tr -d '[' || true)
  echo "INSTALL_DATE=${d:-unknown}" > /etc/kirk-release
fi
# record the version; kirk-branding (and its pacman hook) read it from here
if grep -q '^VERSION=' /etc/kirk-release; then
  sed -i "s|^VERSION=.*|VERSION=$VERSION|" /etc/kirk-release
else
  sed -i "1i VERSION=$VERSION" /etc/kirk-release
fi

echo "== hardware support =="
install -Dm755 "$SRC"/usr/local/bin/kirk-detect /usr/local/bin/kirk-detect
eval "$(/usr/local/bin/kirk-detect)"
echo "This computer: $(/usr/local/bin/kirk-detect --summary)"
HW=$HERE/overlay/hardware
set_release_key() {
  if grep -q "^$1=" /etc/kirk-release; then sed -i "s|^$1=.*|$1=$2|" /etc/kirk-release
  else echo "$1=$2" >> /etc/kirk-release; fi
}
set_release_key HW_MAC "$KIRK_IS_MAC"
set_release_key HW_BROADCOM_WL "$KIRK_BROADCOM_WL"

if [[ $KIRK_BROADCOM_WL == yes ]]; then
  pacman -S --needed --noconfirm broadcom-wl-dkms
  install -Dm644 "$HW"/broadcom-wl/etc/modprobe.d/broadcom-wl.conf /etc/modprobe.d/broadcom-wl.conf
  install -Dm644 "$HW"/broadcom-wl/etc/modules-load.d/broadcom-wl.conf /etc/modules-load.d/broadcom-wl.conf
  # earlier versions' names for the same two files; removed only now that the new ones are in
  # place, so the Wi-Fi setup is never missing
  rm -f /etc/modprobe.d/mba-wifi.conf /etc/modules-load.d/wl.conf
elif [[ -f /etc/modprobe.d/mba-wifi.conf ]]; then
  echo "NOTE: no Broadcom chip that needs wl was found, but an earlier version set wl up here."
  echo "      Left as it is, in case Wi-Fi depends on it: /etc/modprobe.d/mba-wifi.conf"
fi

# the Mac suspend fix's earlier name
if [[ -f /etc/systemd/system/mba-fix-wakeup.service ]]; then
  systemctl disable mba-fix-wakeup.service 2>/dev/null || true
  rm -f /etc/systemd/system/mba-fix-wakeup.service /usr/local/bin/mba-fix-wakeup
fi
if [[ $KIRK_IS_MAC == yes ]]; then
  install -Dm755 "$HW"/mac/usr/local/bin/mac-fix-wakeup /usr/local/bin/mac-fix-wakeup
  install -Dm755 "$HW"/mac/usr/local/bin/facetimehd-setup /usr/local/bin/facetimehd-setup
  install -Dm644 "$HW"/mac/etc/systemd/system/mac-fix-wakeup.service /etc/systemd/system/mac-fix-wakeup.service
  install -Dm644 "$HW"/mac/etc/modprobe.d/hid_apple.conf /etc/modprobe.d/hid_apple.conf
  systemctl daemon-reload
  systemctl enable --now mac-fix-wakeup.service || true
else
  systemctl daemon-reload
fi

echo "== name in os-release and login banner =="
/usr/local/bin/kirk-branding

echo "== boot splash =="
# This rebuilds the initramfs on a system that boots fine today, so: snapshot first (Btrfs), back up
# mkinitcpio.conf, and put everything back automatically if the rebuild fails.
SPLASH_OK=no
if [[ $(findmnt -no FSTYPE /) == btrfs ]] && command -v timeshift >/dev/null; then
  timeshift --create --comments "before boot splash" --scripted >/dev/null 2>&1 \
    && echo "Timeshift snapshot taken." || echo "(snapshot skipped)"
fi
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.pre-splash
sed -i -E '/^HOOKS=/{/[( ]plymouth[ )]/!s/([( ])(udev|systemd)([ )])/\1\2 plymouth\3/}' /etc/mkinitcpio.conf
if ! grep -qE '^HOOKS=.*[( ]plymouth[ )]' /etc/mkinitcpio.conf; then
  echo "WARNING: couldn't find udev or systemd in HOOKS, so the splash was not enabled."
  cp /etc/mkinitcpio.conf.pre-splash /etc/mkinitcpio.conf
else
  plymouth-set-default-theme kirkus
  if mkinitcpio -P; then
    SPLASH_OK=yes
    echo "Boot splash installed."
    rm -rf /usr/share/plymouth/themes/kirk-arch     # the previous name's theme, no longer used
  else
    echo "WARNING: rebuilding the boot image failed. Restoring the previous setup..."
    cp /etc/mkinitcpio.conf.pre-splash /etc/mkinitcpio.conf
    mkinitcpio -P && echo "Restored. Your system boots exactly as before." \
      || echo "!! Restore also failed. Do NOT reboot; paste this output to get help."
  fi
fi

echo "== GRUB menu name and timer =="
# Set KEY=VALUE in a GRUB defaults file: replace the first (possibly commented-out) line, else append.
set_grub_var() {
  local key=$1 val=$2 f=$3
  if grep -qE "^#?[[:space:]]*$key=" "$f"; then
    sed -i -E "0,/^#?[[:space:]]*$key=/s|^#?[[:space:]]*$key=.*|$key=$val|" "$f"
  else
    echo "$key=$val" >> "$f"
  fi
}
set_grub_var GRUB_TIMEOUT 2 /etc/default/grub
set_grub_var GRUB_TIMEOUT_STYLE hidden /etc/default/grub
# GRUB theme: the boot splash as the menu background (seen when you press Esc at boot).
set_grub_var GRUB_THEME '"/boot/grub/themes/kirkus/theme.txt"' /etc/default/grub
set_grub_var GRUB_TERMINAL_OUTPUT gfxterm /etc/default/grub
set_grub_var GRUB_GFXMODE auto /etc/default/grub
# keep the graphics mode into Linux, so GRUB hands over to the splash without a flicker
set_grub_var GRUB_GFXPAYLOAD_LINUX keep /etc/default/grub
/usr/local/bin/kirk-grub-theme-font || true
sed -i "s|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR=\"$BRAND\"|" /etc/default/grub
if [[ -f /etc/default/grub-btrfs/config ]]; then
  if grep -q '^GRUB_BTRFS_SUBMENUNAME=' /etc/default/grub-btrfs/config; then
    sed -i "s|^GRUB_BTRFS_SUBMENUNAME=.*|GRUB_BTRFS_SUBMENUNAME=\"$BRAND snapshots\"|" /etc/default/grub-btrfs/config
  else
    echo "GRUB_BTRFS_SUBMENUNAME=\"$BRAND snapshots\"" >> /etc/default/grub-btrfs/config
  fi
fi
# Only turn on the splash if the boot image was rebuilt with it.
if [[ $SPLASH_OK == yes ]]; then
  sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/{/splash/!s/"$/ splash"/}' /etc/default/grub
fi
# grub-mkconfig writes grub.cfg.new and only replaces grub.cfg if the new one passes its syntax
# check, so a failure here leaves your current, working boot menu in place.
if grub-mkconfig -o /boot/grub/grub.cfg; then
  echo "GRUB menu regenerated."
  # the menu now uses the kirkus theme, so the previous name's copy can go
  grep -q 'themes/kirk-arch/' /boot/grub/grub.cfg || rm -rf /boot/grub/themes/kirk-arch
else
  echo "WARNING: grub-mkconfig failed; your existing grub.cfg was left untouched and still boots."
fi

cat <<MSG

Done. Log out and back in to see the new logo. Then:
  - System Settings > About this System (or "About This Computer" in the app menu)
  - Wallpaper: right-click the desktop > Configure Desktop and Wallpaper, and pick
    /usr/share/backgrounds/kirkus.svg if it didn't switch on its own.
MSG
echo "Preview of the extra About lines:"
for s in model battery storage installed; do /usr/local/bin/kirk-about-$s | paste -sd' '; done
