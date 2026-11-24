#!/usr/bin/env bash
# Installer for kirkus. Asks a few questions, checking each answer straight away, then runs
# kirk-install-backend. Nothing on disk changes until the final "yes".
# KIRK_FS / KIRK_ENGINE set beforehand become the defaults of the advanced options.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root."; exit 1; }

ZONEINFO=/usr/share/zoneinfo
LOCALES=/usr/share/i18n/SUPPORTED
KEYMAPS=/usr/share/kbd/keymaps
XKB_RULES=/usr/share/X11/xkb/rules/base.lst
BACKEND=/usr/local/bin/kirk-install-backend
ESP_GUID=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
MIN_FREE_MIB=15360   # keep in step with kirk-install-backend

b=$'\e[1m'; dim=$'\e[2m'; yel=$'\e[33m'; off=$'\e[0m'
heading() { echo; echo "${b}$*${off}"; }
problem() { echo "  ${yel}$*${off}"; }

# ask VAR PROMPT [DEFAULT]: one line of input, with the default shown and used for an empty answer
ask() {
  local _a _p=$2
  [[ -n ${3-} ]] && _p+=" [$3]"
  read -rp "$_p: " _a
  printf -v "$1" '%s' "${_a:-${3-}}"
}

# choose MAX [back]: read a number from 1 to MAX (or 0 with "back") into CHOICE, asking again until valid
choose() {
  local a lo=1; [[ ${2-} == back ]] && lo=0
  while true; do
    read -rp "Type a number: " a
    if [[ $a =~ ^[0-9]+$ ]] && (( 10#$a >= lo && 10#$a <= $1 )); then CHOICE=$((10#$a)); return; fi
    problem "Please type a number from $lo to $1."
  done
}

yes_no() {   # yes_no PROMPT DEFAULT(y|n)
  local a
  read -rp "$1 " a
  a=${a:-$2}
  [[ $a == [Yy]* ]]
}

# ---------------------------------------------------------------- internet
online() { ping -c1 -W3 archlinux.org >/dev/null 2>&1; }
while ! online; do
  echo "You're not connected to the internet yet, and the installer needs it."
  yes_no "Open Wi-Fi setup now? [Y/n]" y || { echo "Connect with 'nmtui', then run ./install.sh again."; exit 1; }
  nmtui     # shows the instructions again when it closes
  sleep 2   # give the new connection a moment
done

echo "This computer: $(/usr/local/bin/kirk-detect --summary)"

# ---------------------------------------------------------------- keyboard
# console keymap | X11 layout | name | usual language setting
KEYBOARDS=(
  "us|us|English (US)|en_US"
  "uk|gb|English (UK)|en_GB"
  "de-latin1|de|German|de_DE"
  "fr-latin1|fr|French|fr_FR"
  "es|es|Spanish|es_ES"
  "it|it|Italian|it_IT"
  "pt-latin1|pt|Portuguese|pt_PT"
  "br-abnt2|br|Portuguese (Brazil)|pt_BR"
  "de_CH-latin1|ch|Swiss German|de_CH"
  "nl|nl|Dutch|nl_NL"
  "sv-latin1|se|Swedish|sv_SE"
  "no-latin1|no|Norwegian|nb_NO"
  "dk-latin1|dk|Danish|da_DK"
  "fi|fi|Finnish|fi_FI"
  "pl|pl|Polish|pl_PL"
  "cf|ca|French (Canada)|fr_CA"
)
console_keymap_exists() { [[ -n $(find "$KEYMAPS" -name "$1.map.gz" -print -quit 2>/dev/null) ]]; }
xkb_layout_exists() {
  [[ -r $XKB_RULES ]] || return 0   # can't check, so trust it
  awk -v l="$1" '/^! layout/{s=1; next} /^!/{s=0} s && $1==l {f=1} END{exit !f}' "$XKB_RULES"
}

heading "Keyboard"
for i in "${!KEYBOARDS[@]}"; do
  IFS='|' read -r _ _ name _ <<<"${KEYBOARDS[$i]}"
  printf '  %2d) %s\n' $((i + 1)) "$name"
done
echo "  Or type a layout code, such as cz or hu."
while true; do
  ask kb "Keyboard" 1
  if [[ $kb =~ ^[0-9]+$ ]] && (( 10#$kb >= 1 && 10#$kb <= ${#KEYBOARDS[@]} )); then
    IFS='|' read -r KIRK_KEYMAP KIRK_XKB_LAYOUT KB_NAME LANG_GUESS <<<"${KEYBOARDS[$((10#$kb - 1))]}"
    break
  elif [[ $kb =~ ^[a-z]{2,3}$ ]] && xkb_layout_exists "$kb"; then
    KIRK_XKB_LAYOUT=$kb; KB_NAME=$kb; LANG_GUESS=en_US
    if console_keymap_exists "$kb"; then KIRK_KEYMAP=$kb; else KIRK_KEYMAP=us; fi
    break
  fi
  problem "Type a number from the list, or a two- or three-letter layout code."
done
console_keymap_exists "$KIRK_KEYMAP" || KIRK_KEYMAP=us
# Use it right away, so the password you type now is the password you type later.
if [[ -n ${DISPLAY-} ]]; then setxkbmap "$KIRK_XKB_LAYOUT" 2>/dev/null || true; fi
loadkeys "$KIRK_KEYMAP" >/dev/null 2>&1 || true

# ---------------------------------------------------------------- where to install
# lsblk -P prints KEY="value" pairs, with awkward characters escaped as \xNN
field() { if [[ $2 =~ (^|[[:space:]])$1=\"([^\"]*)\" ]]; then printf '%b' "${BASH_REMATCH[2]}"; fi; }
largest_free_mib() {
  parted -m -s "$1" unit MiB print free 2>/dev/null |
    awk -F: '$5=="free;"{gsub("MiB","",$4); if ($4+0>m) m=$4+0} END{printf "%d", m}'
}
# The USB stick kirkus is running from: never offered as a place to install.
LIVE_SRC=$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null || true)
LIVE_DISK=""
if [[ -n $LIVE_SRC ]]; then
  LIVE_DISK=$(lsblk -npo PKNAME "$LIVE_SRC" 2>/dev/null | head -1 || true)
  LIVE_DISK=${LIVE_DISK:-$LIVE_SRC}
fi

# What's on a disk, for telling disks apart: "Windows (ntfs), EFI (vfat)" or "empty"
disk_contents() {
  local line name label ptype fs s out=() n=0
  while IFS= read -r line; do
    [[ $(field TYPE "$line") == part ]] || continue
    label=$(field LABEL "$line"); ptype=$(field PARTTYPENAME "$line"); fs=$(field FSTYPE "$line")
    name=${label:-${ptype:-partition}}
    n=$((n + 1))
    if (( n <= 4 )); then out+=("$name${fs:+ ($fs)}"); fi
  done < <(lsblk -npP -o TYPE,FSTYPE,LABEL,PARTTYPENAME "$1" 2>/dev/null)
  if (( n > 4 )); then out+=("and $((n - 4)) more"); fi
  if (( n == 0 )); then echo "empty"; else printf -v s '%s, ' "${out[@]}"; echo "${s%, }"; fi
}

DISKS=(); DISK_DESC=()
find_disks() {
  local line name
  DISKS=(); DISK_DESC=()
  while IFS= read -r line; do
    name=$(field NAME "$line")
    [[ $(field TYPE "$line") == disk && $(field RO "$line") == 0 ]] || continue
    [[ $name == "$LIVE_DISK" || $name == /dev/zram* || $name == /dev/loop* ]] && continue
    local model tran
    model=$(field MODEL "$line"); tran=$(field TRAN "$line")
    model=${model%"${model##*[![:space:]]}"}
    DISKS+=("$name")
    DISK_DESC+=("$(field SIZE "$line")  ${model:-disk}${tran:+ ($tran)}")
  done < <(lsblk -dpnP -o NAME,TYPE,RO,SIZE,TRAN,MODEL)
}

show_disks() {   # show_disks [free]: numbered list, with free space when asked
  local i free
  for i in "${!DISKS[@]}"; do
    printf '  %d) %s  %s\n' $((i + 1)) "${DISKS[$i]}" "${DISK_DESC[$i]}"
    if [[ ${1-} == free ]]; then
      free=$(largest_free_mib "${DISKS[$i]}")
      echo "     ${dim}has: $(disk_contents "${DISKS[$i]}"); free space: $(( ${free:-0} / 1024 )) GB${off}"
    else
      echo "     ${dim}has: $(disk_contents "${DISKS[$i]}")${off}"
    fi
  done
  echo "  0) Go back"
}

# Partitions on the disks we may use: PARTS (to install on) and ESPS (EFI partitions to reuse)
PARTS=(); PART_DESC=(); ESPS=(); ESP_DESC=()
find_partitions() {
  local d line name fs label ptype size desc
  PARTS=(); PART_DESC=(); ESPS=(); ESP_DESC=()
  for d in "${DISKS[@]}"; do
    while IFS= read -r line; do
      [[ $(field TYPE "$line") == part ]] || continue
      name=$(field NAME "$line"); fs=$(field FSTYPE "$line"); label=$(field LABEL "$line")
      ptype=$(field PARTTYPE "$line"); size=$(field SIZE "$line")
      if findmnt -rn -S "$name" >/dev/null 2>&1; then continue; fi   # in use right now
      desc="$size  ${label:-$(field PARTTYPENAME "$line")}${fs:+ ($fs)}"
      if [[ ${ptype,,} == "$ESP_GUID" ]]; then
        if [[ $fs == vfat ]]; then ESPS+=("$name"); ESP_DESC+=("$desc"); fi
      else
        PARTS+=("$name"); PART_DESC+=("$desc")
      fi
    done < <(lsblk -npP -o NAME,TYPE,SIZE,FSTYPE,LABEL,PARTTYPE,PARTTYPENAME "$d" 2>/dev/null)
  done
}

find_disks
if (( ${#DISKS[@]} == 0 )); then
  echo "No disk was found to install kirkus on (the USB stick kirkus is running from doesn't count)."
  exit 1
fi

export KIRK_MODE KIRK_DISK="" KIRK_ROOT="" KIRK_ESP=""
while true; do
  heading "How do you want to install kirkus?"
  echo "  1) Erase a whole disk (removes everything on it, including any other system)"
  echo "  2) Install in free space, keeping the systems already there (shrink macOS or Windows first)"
  echo "  3) Install to a partition you've made (it gets erased), reusing an existing EFI partition"
  choose 3

  case $CHOICE in
    1)
      heading "Which disk should be erased?"
      show_disks
      choose ${#DISKS[@]} back; (( CHOICE == 0 )) && continue
      KIRK_MODE=wipe; KIRK_DISK=${DISKS[$((CHOICE - 1))]}
      TARGET="erase all of $KIRK_DISK (${DISK_DESC[$((CHOICE - 1))]}), which has: $(disk_contents "$KIRK_DISK")"
      break ;;
    2)
      heading "Which disk has the free space?"
      show_disks free
      while true; do
        choose ${#DISKS[@]} back; (( CHOICE == 0 )) && continue 2
        d=${DISKS[$((CHOICE - 1))]}
        need=$MIN_FREE_MIB
        [[ $(lsblk -npo PARTTYPE "$d" 2>/dev/null) == *"$ESP_GUID"* ]] || need=$((need + 512))
        free=$(largest_free_mib "$d")
        (( ${free:-0} >= need )) && break
        problem "$d only has $(( ${free:-0} / 1024 )) GB of free space in one piece; kirkus needs $(( (need + 1023) / 1024 )) GB."
        problem "Shrink the other system first, or choose another disk (0 to go back)."
      done
      KIRK_MODE=freespace; KIRK_DISK=$d
      TARGET="the free space on $KIRK_DISK (${DISK_DESC[$((CHOICE - 1))]}); everything else is kept"
      break ;;
    3)
      find_partitions
      if (( ${#ESPS[@]} == 0 )); then
        problem "No EFI partition was found to reuse, so this option can't be used. Choose 1 or 2."
        continue
      fi
      if (( ${#PARTS[@]} == 0 )); then
        problem "No partition was found to install on. Make one first, or choose 1 or 2."
        continue
      fi
      heading "Which partition should kirkus go on? It will be erased."
      for i in "${!PARTS[@]}"; do printf '  %d) %s  %s\n' $((i + 1)) "${PARTS[$i]}" "${PART_DESC[$i]}"; done
      echo "  0) Go back"
      choose ${#PARTS[@]} back; (( CHOICE == 0 )) && continue
      KIRK_ROOT=${PARTS[$((CHOICE - 1))]}; root_desc=${PART_DESC[$((CHOICE - 1))]}
      if (( ${#ESPS[@]} == 1 )); then
        KIRK_ESP=${ESPS[0]}
        echo "Using the EFI partition $KIRK_ESP (${ESP_DESC[0]})."
      else
        heading "Which EFI partition should kirkus share?"
        for i in "${!ESPS[@]}"; do printf '  %d) %s  %s\n' $((i + 1)) "${ESPS[$i]}" "${ESP_DESC[$i]}"; done
        echo "  0) Go back"
        choose ${#ESPS[@]} back; (( CHOICE == 0 )) && continue
        KIRK_ESP=${ESPS[$((CHOICE - 1))]}
      fi
      KIRK_MODE=partition
      TARGET="erase the partition $KIRK_ROOT ($root_desc), sharing the EFI partition $KIRK_ESP"
      break ;;
  esac
done

# ---------------------------------------------------------------- you and this computer
heading "About you and this computer"
while true; do
  ask KIRK_HOST "Name for this computer" kirkus
  [[ $KIRK_HOST =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]] && break
  problem "Use letters, numbers and dashes only, with no spaces (for example: alex-laptop)."
done

# names the installed system uses itself (the live USB doesn't have all of them)
RESERVED=" root bin daemon mail ftp http nobody dbus sddm polkitd avahi colord flatpak geoclue git "
RESERVED+=" rtkit usbmux uuidd tss alpm dhcpcd nm-openvpn openvpn brltty cups saned ntp "
user_default=""
while true; do
  ask KIRK_USER "Your username" "$user_default"
  if [[ ! $KIRK_USER =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    problem "Use lowercase letters, numbers, - and _ only, starting with a letter (for example: alex)."
    low=${KIRK_USER,,}; low=${low// /}
    [[ $low =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && user_default=$low
  elif [[ $RESERVED == *" $KIRK_USER "* || $KIRK_USER == systemd-* ]] || getent passwd "$KIRK_USER" >/dev/null; then
    problem "\"$KIRK_USER\" is used by the system. Please choose another name."
  else
    break
  fi
done

while true; do
  read -rsp "Password: " KIRK_PASSWORD; echo
  if [[ -z $KIRK_PASSWORD ]]; then problem "The password can't be empty."; continue; fi
  read -rsp "Type it again: " p2; echo
  [[ $KIRK_PASSWORD == "$p2" ]] && break
  problem "Those didn't match. Let's try again."
done
unset p2

# ---------------------------------------------------------------- time zone and language
valid_tz() {
  [[ -n $1 && $1 != /* && $1 != *..* && $1 != posix/* && $1 != right/* && -f $ZONEINFO/$1 ]]
}
all_tz() {
  (cd "$ZONEINFO" && find . -type f ! -path './posix/*' ! -path './right/*' -printf '%P\n') |
    grep -E '^[A-Z][A-Za-z_-]*(/[A-Za-z0-9_+-]+)+$|^UTC$' | sort
}
# A guess from the internet connection's location. Only a suggestion; you can type another.
tz_default=$(curl -fsS --max-time 5 https://ipapi.co/timezone 2>/dev/null || true)
valid_tz "$tz_default" || tz_default=UTC

heading "Time zone"
echo "  ${dim}Like America/New_York or Europe/London. Typing just a city works too.${off}"
while true; do
  ask tz "Time zone" "$tz_default"
  tz=${tz// /_}
  valid_tz "$tz" && { KIRK_TZ=$tz; break; }
  mapfile -t found < <(all_tz | grep -iF -- "$tz" || true)
  exact=$(printf '%s\n' "${found[@]}" | grep -ixF -- "$tz" | head -1 || true)
  if [[ -n $exact ]]; then KIRK_TZ=$exact; break; fi
  city=$(printf '%s\n' "${found[@]}" | grep -i -- "/${tz//./\\.}\$" || true)
  if [[ -n $city && $city != *$'\n'* ]]; then echo "  Using $city."; KIRK_TZ=$city; break; fi
  if (( ${#found[@]} == 1 )); then
    echo "  Found ${found[0]}. Press Enter to use it."
    tz_default=${found[0]}
  elif (( ${#found[@]} > 1 )); then
    echo "  Did you mean one of these?"
    printf '    %s\n' "${found[@]:0:10}"
    (( ${#found[@]} > 10 )) && echo "    ... and $(( ${#found[@]} - 10 )) more. Try a longer name."
  else
    problem "\"$tz\" isn't a time zone kirkus knows. Try a nearby big city, such as Chicago or Paris."
  fi
done

heading "Language setting"
echo "  ${dim}Sets the date and number formats, and the language where it's available.${off}"
while true; do
  ask loc "Language setting" "$LANG_GUESS.UTF-8"
  # tidy up en_gb, en_GB, en_GB.utf8 and so on into en_GB.UTF-8
  if [[ $loc =~ ^([A-Za-z]{2,3})_([A-Za-z]{2})(\.[Uu][Tt][Ff]-?8)?$ ]]; then
    loc="${BASH_REMATCH[1],,}_${BASH_REMATCH[2]^^}.UTF-8"
  fi
  grep -qxF -- "$loc UTF-8" "$LOCALES" 2>/dev/null && { KIRK_LOCALE=$loc; break; }
  problem "\"$loc\" isn't available. It looks like en_US.UTF-8: language, country, then .UTF-8."
done

# ---------------------------------------------------------------- advanced
KIRK_FS=${KIRK_FS:-btrfs}; KIRK_ENGINE=${KIRK_ENGINE:-archinstall}
echo
if yes_no "Change advanced options (filesystem, install method)? Most people don't need to. [y/N]" n; then
  heading "Filesystem"
  echo "  1) Btrfs, with snapshots for undoing a bad update (recommended)"
  echo "  2) ext4, without snapshots"
  choose 2; [[ $CHOICE == 2 ]] && KIRK_FS=ext4 || KIRK_FS=btrfs
  heading "Install method"
  echo "  1) archinstall, Arch's own installer, falling back to pacstrap if it fails (recommended)"
  echo "  2) pacstrap only"
  choose 2; [[ $CHOICE == 2 ]] && KIRK_ENGINE=pacstrap || KIRK_ENGINE=archinstall
fi

# ---------------------------------------------------------------- confirm
case $KIRK_FS in btrfs) fs_desc="Btrfs, with snapshots" ;; *) fs_desc="ext4, no snapshots" ;; esac
heading "Ready to install"
echo "  Install:     $TARGET"
echo "  Keyboard:    $KB_NAME"
echo "  Computer:    $KIRK_HOST"
echo "  Username:    $KIRK_USER"
echo "  Time zone:   $KIRK_TZ"
echo "  Language:    $KIRK_LOCALE"
echo "  Filesystem:  $fs_desc"
[[ $KIRK_ENGINE == archinstall ]] || echo "  Method:      $KIRK_ENGINE"
echo
echo "${yel}${b}Nothing has been changed yet. Data on the target above will be lost.${off}"
read -rp "Type 'yes' to install, or anything else to stop: " c
[[ $c == yes ]] || { echo "Stopped. Nothing was changed."; exit 1; }
export KIRK_FS KIRK_ENGINE KIRK_HOST KIRK_USER KIRK_PASSWORD KIRK_TZ KIRK_LOCALE KIRK_KEYMAP KIRK_XKB_LAYOUT
exec "$BACKEND"
