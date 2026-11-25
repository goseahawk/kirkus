#!/usr/bin/env bash
# Updates an installed kirkus system to this version of the project, without reinstalling.
#
# Run it from the project folder on the installed system:
#     sudo ./apply-to-installed.sh
#
# kirk-update runs it automatically for each new release (see UPDATING.md). The version it records
# is today's date, or set KIRK_VERSION=26.11.18 to choose it.
#
# It installs the same files and settings as the installer: branding, boot splash, GRUB theme, login
# screen, Plasma splash, About page, update hooks, firewall and hardware support. It never touches the EFI
# partition or reinstalls GRUB, so the way your computer boots stays as it is. Safe to run again.
set -euo pipefail
[[ $EUID -eq 0 ]] || exec sudo KIRK_VERSION="${KIRK_VERSION:-}" "$0" "$@"

VERSION=${KIRK_VERSION:-$(date +%y.%m.%d)}
[[ $VERSION =~ ^[0-9]{2}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?$ ]] || { echo "Bad version '$VERSION': use YY.MM.DD or YY.MM.DD.N, e.g. 26.11.18 or 26.11.18.1"; exit 1; }
BRAND="kirkus $VERSION"
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$HERE/overlay/installed
HW=$HERE/overlay/hardware
[[ -d $SRC && -d $HW ]] || { echo "Run this from inside the project folder."; exit 1; }

# Copy a tree onto /, file by file, owned by root. Programs (usr/local/bin, etc/grub.d) get 755,
# everything else 644. Directories that already exist keep their permissions. Files listed in KEEP
# are only installed if missing, so your own settings in them survive updates.
KEEP=(etc/kirk-update.conf)
copy_tree() {
  local from=$1 rel mode k skip
  while IFS= read -r -d '' rel; do
    rel=${rel#./}
    skip=no
    for k in "${KEEP[@]}"; do [[ $rel == "$k" && -e /$rel ]] && skip=yes; done
    [[ $skip == yes ]] && continue
    case $rel in
      usr/local/bin/*|etc/grub.d/*) mode=755 ;;
      *) mode=644 ;;
    esac
    install -D -o root -g root -m "$mode" "$from/$rel" "/$rel"
  done < <(cd "$from" && find . -type f -print0)
}

# ---------------------------------------------------------------------------------------- hardware
eval "$(sh "$SRC"/usr/local/bin/kirk-detect)"
echo "This computer: $(sh "$SRC"/usr/local/bin/kirk-detect --summary)"

# ---------------------------------------------------------------------------------------- packages
echo "== packages =="
PKGS=(kinfocenter fastfetch discover flatpak kdialog xf86-input-libinput plymouth power-profiles-daemon
      zram-generator ufw plasma-firewall)
case $KIRK_CPU in
  intel) PKGS+=(intel-ucode thermald) ;;
  amd)   PKGS+=(amd-ucode) ;;
esac
[[ $KIRK_GPU_INTEL == yes ]] && PKGS+=(vulkan-intel intel-media-driver)
[[ $KIRK_GPU_AMD == yes ]] && PKGS+=(vulkan-radeon)
[[ $KIRK_BROADCOM_WL == yes ]] && PKGS+=(broadcom-wl-dkms)
pacman -S --needed --noconfirm "${PKGS[@]}"

# ------------------------------------------------------------------------------------------- files
echo "== kirkus files =="
# Theme folders belong to kirkus entirely: replace them, so files a newer version dropped go too.
rm -rf /usr/share/plymouth/themes/kirkus /boot/grub/themes/kirkus /usr/share/sddm/themes/kirkus \
       /usr/share/plasma/look-and-feel/org.kirkus.splash /usr/share/kirkus
copy_tree "$SRC"
[[ $KIRK_BROADCOM_WL == yes ]] && copy_tree "$HW"/broadcom-wl
[[ $KIRK_IS_MAC == yes ]] && copy_tree "$HW"/mac
systemctl daemon-reload

# version and hardware, read by kirk-branding, the About page and kirk-update
touch /etc/kirk-release
set_release_key() {
  if grep -q "^$1=" /etc/kirk-release; then sed -i "s|^$1=.*|$1=$2|" /etc/kirk-release
  else echo "$1=$2" >> /etc/kirk-release; fi
}
set_release_key VERSION "$VERSION"
set_release_key HW_MAC "$KIRK_IS_MAC"
set_release_key HW_BROADCOM_WL "$KIRK_BROADCOM_WL"
/usr/local/bin/kirk-branding

# ---------------------------------------------------------------------------------------- services
systemctl enable power-profiles-daemon.service || true
if [[ $KIRK_CPU == intel ]]; then systemctl enable thermald.service || true; fi
if [[ $KIRK_IS_MAC == yes ]]; then systemctl enable --now mac-fix-wakeup.service || true; fi
# firewall: turned on once (see kirk-firewall-setup); after that it's left as you set it
systemctl enable --now kirk-firewall-setup.service || true
# grub-btrfsd picks up its Timeshift settings on restart
systemctl try-restart grub-btrfsd.service 2>/dev/null || true
# weekly automatic updates, unless you've turned them off
if grep -q '^AUTO_SYSTEM_UPDATE=no' /etc/kirk-update.conf 2>/dev/null; then
  systemctl disable --now kirk-auto-update.timer 2>/dev/null || true
else
  systemctl enable --now kirk-auto-update.timer || true
fi

# ----------------------------------------------------------------------------------- desktop & apps
echo "== desktop =="
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
  || echo "Could not add Flathub (offline?). Run this again later to add it."
/usr/local/bin/kirk-install-fonts || true
/usr/local/bin/kirk-login-theme kirkus
gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true
# The Plasma splash is the default for everyone via /etc/xdg/ksplashrc; set it for you as well, in
# case you picked a different one before.
if [[ -n ${SUDO_USER:-} ]] && command -v kwriteconfig6 >/dev/null; then
  sudo -H -u "$SUDO_USER" kwriteconfig6 --file ksplashrc --group KSplash --key Engine KSplashQML || true
  sudo -H -u "$SUDO_USER" kwriteconfig6 --file ksplashrc --group KSplash --key Theme org.kirkus.splash || true
fi

# ------------------------------------------------------------------------------------- boot splash
echo "== boot splash =="
# Rebuilding the boot image on a system that boots fine today: snapshot first (Btrfs), keep a copy
# of mkinitcpio.conf, and put it back automatically if the rebuild fails.
SPLASH_OK=no
if [[ $(findmnt -no FSTYPE /) == btrfs && -f /etc/timeshift/timeshift.json ]] && command -v timeshift >/dev/null; then
  timeshift --create --comments "kirkus $VERSION: before update" --scripted >/dev/null 2>&1 \
    && echo "Timeshift snapshot taken." || echo "(snapshot skipped)"
fi
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.kirkus-backup
sed -i -E '/^HOOKS=/{/[( ]plymouth[ )]/!s/([( ])(udev|systemd)([ )])/\1\2 plymouth\3/}' /etc/mkinitcpio.conf
if ! grep -qE '^HOOKS=.*[( ]plymouth[ )]' /etc/mkinitcpio.conf; then
  echo "WARNING: couldn't find udev or systemd in HOOKS, so the boot splash was not enabled."
  cp /etc/mkinitcpio.conf.kirkus-backup /etc/mkinitcpio.conf
else
  plymouth-set-default-theme kirkus
  if mkinitcpio -P; then
    SPLASH_OK=yes
  else
    echo "WARNING: rebuilding the boot image failed. Restoring the previous setup..."
    cp /etc/mkinitcpio.conf.kirkus-backup /etc/mkinitcpio.conf
    mkinitcpio -P && echo "Restored. Your system boots exactly as before." \
      || echo "!! Restore also failed. Do NOT restart; paste this output to get help."
  fi
fi

# -------------------------------------------------------------------------------------------- GRUB
echo "== GRUB menu =="
# Set KEY=VALUE in a defaults file: replace the first (possibly commented-out) line, else append.
set_var() {
  local key=$1 val=$2 f=$3
  if grep -qE "^#?[[:space:]]*$key=" "$f"; then
    sed -i -E "0,/^#?[[:space:]]*$key=/s|^#?[[:space:]]*$key=.*|$key=$val|" "$f"
  else
    echo "$key=$val" >> "$f"
  fi
}
G=/etc/default/grub
set_var GRUB_DISTRIBUTOR "\"$BRAND\"" $G
set_var GRUB_TIMEOUT 2 $G
set_var GRUB_TIMEOUT_STYLE hidden $G
set_var GRUB_THEME '"/boot/grub/themes/kirkus/theme.txt"' $G
set_var GRUB_TERMINAL_OUTPUT gfxterm $G
set_var GRUB_GFXMODE auto $G
set_var GRUB_GFXPAYLOAD_LINUX keep $G      # no flicker between GRUB and the boot splash
if [[ $SPLASH_OK == yes ]]; then
  sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/{/splash/!s/"$/ splash"/}' $G
fi
if [[ -f /etc/default/grub-btrfs/config ]]; then
  set_var GRUB_BTRFS_SUBMENUNAME "\"$BRAND snapshots\"" /etc/default/grub-btrfs/config
fi
/usr/local/bin/kirk-grub-theme-font || true
# grub-mkconfig only replaces grub.cfg if the new one passes its syntax check, so a failure here
# leaves your current, working boot menu in place.
grub-mkconfig -o /boot/grub/grub.cfg \
  || echo "WARNING: grub-mkconfig failed; your existing boot menu was left as it was and still works."

echo
echo "kirkus $VERSION is installed. Restart to see everything."
