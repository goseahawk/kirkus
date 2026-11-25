# Developing kirkus

How kirkus is put together, for anyone changing it or building their own ISO. If you just want to
install and use kirkus, see the [README](README.md).

## Project layout

| Path | What it is |
|---|---|
| `build.sh` | builds the ISO on Arch |
| `build-docker.sh` | builds the ISO on any other OS, in a container |
| `apply-to-installed.sh` | updates an existing install to the current project |
| `UPDATING.md` | how to keep an installed system up to date |
| `DEVELOPMENT.md` | this file |
| `CLAUDE.md` | project notes that Claude Code reads automatically |
| `overlay/airootfs/` | files for the live USB: `install.sh`, `kirk-install-backend`, live Wi-Fi detection |
| `overlay/installed/` | files copied into every installed system (incl. `kirk-detect`) |
| `overlay/hardware/broadcom-wl/` | added only when a chip needs the `wl` driver |
| `overlay/hardware/mac/` | added only on Intel Macs |
| `branding/` | the logo files (`build/`) and the tools that make every screen image from them (`tools/`) |
| `site/` | the download website, published to GitHub Pages by `.github/workflows/website.yml` |
| `tools/` | Intel Mac boot troubleshooting: a read-only diagnosis script and a repair script |

## Building the ISO

To build your own ISO, for example with your own changes:

- **On Arch:** `sudo ./build.sh` (it installs `archiso` if you don't have it).
- **On any other OS** (Fedora, Debian, macOS, Windows with WSL2): `./build-docker.sh`. It needs Docker
  or Podman on an x86_64 computer, and runs the whole Arch build in a throwaway container.

Either way the ISO lands in `out/`, named for today's date (set `KIRK_VERSION=26.11.18` to choose
the version). Expect 30–60 minutes.

## Applying changes to an installed system

Get the project onto the installed computer (`git clone https://github.com/goseahawk/kirkus.git`,
or `git pull` in an existing copy), then run from its folder:

    sudo ./apply-to-installed.sh

It installs the same files and settings as the installer (branding, splash screens, login screen,
About page, update hooks, hardware support) without reinstalling. On Btrfs it takes a snapshot before
rebuilding the boot image. It never touches the EFI partition or reinstalls GRUB, so the way the
computer boots stays as it is, and it's safe to run more than once. The version it records is today's
date; set `KIRK_VERSION=26.11.18` to choose it.

`sudo kirk-update --main` does the same with the newest commit on GitHub's main branch, without a
local copy. It records today's date as the version (never lower than what's installed) and the
commit in `/etc/kirk-release` as `SOURCE=main <commit>`; release updates record
`SOURCE=release <tag>`. Later releases still install once they're newer.

## How updates work

- **Weekly updates:** `kirk-auto-update.timer` runs `kirk-auto-update --auto` 20 minutes after boot
  and every 6 hours. It updates only when 7 days have passed since the last "full system upgrade" in
  `/var/log/pacman.log`, on mains power, not metered, and when no Arch news is newer than that
  upgrade. Then `pacman -Sy archlinux-keyring` and `pacman -Su`, then `flatpak update`. Settings:
  `AUTO_SYSTEM_UPDATE` in `/etc/kirk-update.conf`.
- **kirkus releases:** the pacman hook `zz-kirk-update.hook` starts `kirk-update.service` after any
  upgrade. It waits for pacman to finish, follows `github.com/<repo>/releases/latest`, and applies the
  release with its own `apply-to-installed.sh` if it's newer (compared with `sort -V`). Settings:
  `AUTO_UPDATE` and `REPO` in `/etc/kirk-update.conf`. Updates never overwrite that file.
- Notifications come from `kirk-notify`, which sends to every logged-in Plasma session.

## The installer

### Hardware detection

`kirk-detect` decides what to install, both on the live USB and in the installed system:

| Detected | What gets installed |
|---|---|
| Broadcom **BCM4331, BCM4352 or BCM4360** Wi-Fi (on any computer) | Broadcom's `wl` driver, with the open-source drivers that would grab the chip blocked. Other Broadcom chips, e.g. the BCM4350 in later MacBooks, keep Linux's built-in drivers, which `wl` would break. |
| An **Intel Mac** | Mac support: the instant-wake-from-suspend fix, the Apple keyboard Fn setting, a FaceTime HD webcam helper, and a bootloader setup that never writes to the Mac's firmware settings (see below) |
| Intel / AMD **CPU** | `intel-ucode` + `thermald`, or `amd-ucode` |
| Intel / AMD **graphics** | `vulkan-intel` + `intel-media-driver`, or `vulkan-radeon` |

Run `kirk-detect --summary` to see what it finds. To override it, set `KIRK_IS_MAC=yes|no` or
`KIRK_BROADCOM_WL=yes|no` before running `./install.sh`. The results are recorded in
`/etc/kirk-release`.

### The questions

`install.sh` asks the questions and checks each answer straight away (asking again rather than
quitting), then hands everything to `kirk-install-backend` as `KIRK_*` environment variables.

- **Keyboard:** a short list of common layouts, or any XKB layout code. It's applied to the live
  session at once (`setxkbmap`, `loadkeys`), so the password is typed in the same layout it will be
  used with. The backend writes it to `vconsole.conf` (`KIRK_KEYMAP`) and
  `/etc/X11/xorg.conf.d/00-keyboard.conf` (`KIRK_XKB_LAYOUT`), which SDDM and Plasma use.
- **Disks** are listed with `lsblk`, leaving out the USB stick kirkus is running from
  (`/run/archiso/bootmnt`). Free-space installs check there's room before going on.
- **Time zone:** suggested from `https://ipapi.co/timezone` (5-second timeout, UTC if it fails).
  Typing a city finds the matching zone.
- **Language setting:** suggested from the keyboard, checked against `/usr/share/i18n/SUPPORTED`.
- **Filesystem and install method** are behind "advanced options". `KIRK_FS` and `KIRK_ENGINE` set
  beforehand become their defaults.

### How the install is split up

This project does as little of the installing itself as it can:

| Stage | Who does it | Why |
|---|---|---|
| Partitioning, btrfs subvolumes, mounting | this project | archinstall can't carve a partition out of free space beside another system while reusing its EFI partition |
| Base system, KDE Plasma, locale, mirrors, fstab | **archinstall** | Arch's own maintained installer |
| Bootloader | this project | archinstall's pre-mounted mode has an open bug where `grub-install` fails ([#2054](https://github.com/archlinux/archinstall/issues/2054)); the documented workaround is to run `grub-install` yourself |
| Hardware support, Timeshift, branding, your user account | this project | |

The config given to archinstall uses only `pre_mounted_config`, whose two keys have stayed stable
across releases, rather than its manual-partitioning schema, which changes between versions. If
archinstall fails, the installer falls back to plain `pacstrap` automatically; `KIRK_ENGINE=pacstrap`
forces that. Both produce the same system. archinstall is given a throwaway root password because
it insists on one; your account is created afterwards and root is locked.

## Booting

**On a PC**, GRUB is installed the normal way, with a firmware boot entry called kirkus.

**On an Intel Mac:** GRUB goes only at `EFI/BOOT/BOOTX64.EFI`, the path the Option-key startup manager
lists as "EFI Boot". The installer never writes boot entries to a Mac's firmware with `efibootmgr`,
which has been reported to damage Mac firmware, and never touches macOS's boot files. Hold Option at
startup to choose. If the startup manager doesn't list Linux, make it the default from macOS
Recovery (Cmd+R → Utilities → Terminal):

    diskutil mount disk0s1
    bless --mount /Volumes/EFI --setBoot --nextonly --shortform --file /Volumes/EFI/EFI/BOOT/BOOTX64.EFI

`--nextonly` tries it for one boot; run it again without `--nextonly` to keep it. `tools/` has a
read-only diagnosis script and a repair script for this situation.

### The hidden GRUB menu

GRUB waits 2 seconds with the menu hidden, then boots. **Tap Esc** during that moment to show it (for
the fallback entry or the snapshots submenu). Use Esc rather than F4: on many laptop keyboards the
F-keys are media keys unless you hold Fn.

Those 2 seconds already show the boot splash, so the boot looks like one continuous screen. GRUB can't
do that on its own (its hidden countdown never draws a background), so `/etc/grub.d/06_kirk_splash`
draws the image and runs its own Esc-interruptible wait. If that script is removed or GRUB can't run
it, you get GRUB's normal hidden wait.

When the menu does show, it uses the splash as its background with the entries underneath. Theme files
are in `/boot/grub/themes/kirkus/`. `kirk-grub-theme-font` builds its font from DM Sans,
falling back to Noto Sans or GRUB's built-in font.

To change it, edit `GRUB_TIMEOUT` / `GRUB_TIMEOUT_STYLE` in `/etc/default/grub` (`menu` shows it every
time), then `sudo grub-mkconfig -o /boot/grub/grub.cfg`. Don't set the timeout to 0: the menu can
become unreachable.

## Versions and releases

Each build is versioned by its date as **YY.MM.DD**, e.g. **kirkus 26.11.18**. More builds on the
same day add a number: **26.11.18.1**, **26.11.18.2** and so on. The version
appears in the ISO's boot menu and filename (`kirkus-26.11.18-x86_64.iso`), the live USB's
welcome message, System Settings → About this System, fastfetch, the login banner and the GRUB menu.

- `build.sh` uses the date you build the ISO, and the installer passes it on in `/etc/kirk-release`.
  `apply-to-installed.sh` uses the date you run it. Override either with `KIRK_VERSION=26.11.18`.
- **Publishing a release:** tag it with the version exactly, e.g. `26.11.18` or `26.11.18.1` (no `v`
  in front), and publish it on GitHub. Installed systems pick up the newest published release
  automatically after their next `pacman -Syu`. Drafts and pre-releases aren't picked up, so you can
  test one first.
- os-release gets `NAME="kirkus"`, `PRETTY_NAME="kirkus 26.11.18"`, `VERSION` and
  `VERSION_ID`. pacman resets os-release whenever the `filesystem` package updates, so a hook
  rebuilds it from `/etc/kirk-release`.

## The website

`site/` is the download website, at https://goseahawk.github.io/kirkus/. It's plain HTML and CSS,
with the DM Sans font (SIL Open Font License, `site/fonts/OFL.txt`) bundled so nothing loads from
other sites. `download.js` asks GitHub's API for the latest release and points the button at its
ISO, with the version, size and date; if that fails, the button links to the latest release page.
So publishing a release updates the website by itself.

Any change to `site/` on main is published by the **Website** workflow. One-time setup: Settings →
Pages → Source: **GitHub Actions**.

## Btrfs layout and snapshots

Subvolumes: `@` (/), `@home` (/home), `@log`, `@cache` (pacman cache). Timeshift is pre-configured in
Btrfs mode with daily and weekly snapshots of `@`. Your `/home` is **not** included by default; change
that in Timeshift → Settings → Users.

- A baseline "Fresh install" snapshot is made on first boot.
- A snapshot is taken before upgrades of the kernel, systemd, GRUB, mesa, Plasma and the Wi-Fi driver
  (at most one every 2 hours).
- `grub-btrfs` adds a snapshots submenu to GRUB. Boot any snapshot read-only to test it, then restore
  it for real from Timeshift.
- `sudo timeshift --list`, `sudo timeshift --create`, or the Timeshift app.
- Snapshots live on the same disk, so they protect against a bad update, not a dead disk. Keep real
  backups of /home.
- ext4 skips all of this; choose it in the installer.

## About This Computer

System Settings → **About this System** shows the logo and name with the usual CPU, memory,
graphics and Plasma details, plus four extra lines:

| Line | Source |
|---|---|
| Model | maker and model from the firmware, with friendly names for some Macs (e.g. `MacBookAir7,2` → "MacBook Air (13-inch, Early 2015 or 2017)") |
| Battery | health as % of design capacity, plus charge cycles when the firmware reports them |
| Storage | free / total on `/`, and whether it's Btrfs with snapshots |
| Installed | the install date from `/etc/kirk-release` |

The **About This Computer** entry in the app menu opens it directly. It's wired up by `LOGO=kirkus-logo`
in os-release and `/etc/xdg/kcm-about-distrorc`, which lists the `kirk-about-*` scripts.
KInfoCenter **refuses to open** if one of those scripts prints anything other than exactly two lines,
so keep that rule when editing them.

## Boot splash

A Plymouth theme, `kirkus`, shows the word "kirkus" fading in on black while the system
starts. Files: `/usr/share/plymouth/themes/kirkus/`.

- **See boot messages:** press Esc while the splash is up.
- **Change it:** edit `kirkus.script`, then `sudo plymouth-set-default-theme -R kirkus`.
- **Turn it off:** remove `splash` (and `quiet`, for full messages) from `GRUB_CMDLINE_LINUX_DEFAULT` in
  `/etc/default/grub`, then `sudo grub-mkconfig -o /boot/grub/grub.cfg`.
- If the theme fails to load, Plymouth falls back to text; it never stops the boot.

## Login screen

An SDDM theme, `kirkus`, continues the boot splash: the logo in the same place, the password field
under it, the date and time at the top, and the session plus Sleep / Restart / Shut Down along the
bottom. A wrong password shakes the field; Caps Lock gets a warning.

- **Preview without logging out:** `kirk-login-preview`.
- **Switch theme:** `sudo kirk-login-theme breeze`, and back with `sudo kirk-login-theme`. This also
  updates System Settings' own config, so the two always agree.
- **If the login screen is ever blank:** press Ctrl+Alt+F2, log in, run `sudo kirk-login-theme breeze`,
  then `sudo systemctl restart sddm`.

The lock screen (Super+L) belongs to Plasma, not SDDM, so it's unaffected.

## Desktop theme

The theme is called **kirkus** everywhere System Settings → Colors & Themes shows one, with a light
twin:

| Part | kirkus (the default) | kirkus Light | Where |
|---|---|---|---|
| Global Theme | **kirkus** (`org.kirkus.splash`, named so because it began as the splash alone) | **kirkus Light** (`org.kirkus.light`) | `/usr/share/plasma/look-and-feel/` |
| Colors | **kirkus** (`KirkusDark.colors`): Ink backgrounds, Bone text | **kirkus Light** (`KirkusLight.colors`): Bone backgrounds, Ink text | `/usr/share/color-schemes/` |
| Plasma Style | **kirkus** | **kirkus** | `/usr/share/plasma/desktoptheme/kirkus/` |
| Icons | **kirkus**: Breeze Dark, with the bird as the start icon | **kirkus Light**: Breeze, with the bird | `/usr/share/icons/kirkus*/` |
| Wallpaper | **kirkus**, dark picture | **kirkus**, light picture | `/usr/share/wallpapers/kirkus/` |
| Splash Screen | **kirkus** | **kirkus** | the `org.kirkus.splash` package |

Both use Marigold for selections and focus (with Ink text on it), and KDE's Breeze window borders and
application style, which take their colours from the scheme. Each Global Theme's `contents/defaults`
lists what "Apply" sets. `/etc/xdg/kdeglobals` and `/etc/xdg/plasmarc` make kirkus everyone's
default, and make kirkus Light and kirkus the pair that **Switch to Dark Mode at Night** uses (KDE's
default is Breeze). A new account is fully kirkus from its first frame, with no scripts involved.

- **No panel layout of our own.** New accounts get KDE's own default panel, which always matches the
  installed Plasma. With a copy of it in the kirkus Global Theme, new accounts on Arch's newer Plasma
  got no panel at all.
- **Colours:** `branding/tools/make-color-schemes.py` writes both schemes, the defaults in
  `/etc/xdg/kdeglobals` and `/etc/xdg/plasmarc`, and Konsole's **kirkus** profile and colour scheme
  (`/usr/share/konsole/`, made the default by `/etc/xdg/konsolerc`; anyone who picks another profile
  keeps theirs).
- **Plasma Style:** like KDE's Breeze Dark style, it has no pictures of its own: Plasma draws the
  panel and pop-ups with Breeze's shapes, in the current scheme's colours. Its `plasmarc` names the
  kirkus wallpaper as its default.
- **Icons:** the two icon themes contain only KDE's start icons (`start-here-kde` and friends: KDE's
  logo, a "K" that looked like the old kirkus mark), redrawn as the bird; everything else comes
  from Breeze Dark or Breeze. That's how the Application Launcher shows the bird with no setting at
  all. The bird's body is drawn in the theme's text colour (KDE recolours SVG parts marked
  `ColorScheme-Text`), so it's Bone on a dark panel and Ink on a light one. `FollowsColorScheme=true`
  in their `index.theme` is what lets Breeze's icons take the Marigold accent, as Breeze's own do.
  `make-screens.py` makes them.
- **Wallpaper ("Quiet"):** flat Ink with a large bird one shade lighter; on kirkus Light, flat Bone
  with a bird one shade darker. It's a wallpaper package like KDE's own, with
  `contents/images_dark/` and `contents/images/`, and Plasma picks the one that matches the colour
  scheme. The Global Themes name it (`Image=kirkus`), so it's also the lock screen's wallpaper.
  `/usr/share/backgrounds/kirkus.svg` is the same picture, kept for older accounts that point at it.
  No gradients: on 8-bit screens they show rings.

Existing accounts are brought over once each, at login, by three autostart scripts. Each leaves a
file in `~/.config` so it never runs again:

| Script | Does | Leaves alone |
|---|---|---|
| `kirk-set-theme` | puts the account on the kirkus theme (never panels or widgets) | accounts on any scheme other than KDE's Breeze ones or kirkus (`kirk-theme-4-done`) |
| `kirk-set-wallpaper` | switches desktops showing the older kirkus file or KDE's "Next" to the kirkus wallpaper | any other wallpaper (`kirk-wallpaper-2-done`) |
| `kirk-set-launcher-icon` | puts the bird on the Application Launcher | an icon someone picked (`kirk-launcher-icon-2-done`) |

`kirk-set-theme` runs KDE's Global Theme tool (`plasma-apply-lookandfeel`), then checks each setting
and writes whatever is still wrong into the account's config itself, and tells everything running
to reload. It only leaves its file once the colours really are kirkus, so a failed attempt is
retried at the next login. KDE's apply tools can't be trusted alone: when they think a theme is
already set (and `/etc/xdg` makes them think so) they change nothing and still report success. That's
how an earlier version left accounts that had KDE's Breeze colours saved without a scheme name
stuck on Breeze. It logs to the journal: `journalctl -t kirkus-theme`.

Plasma 6 records a Global Theme's choices in `~/.config/kdedefaults/`, which a Plasma login reads
before `/etc/xdg` (startplasma puts it first in `XDG_CONFIG_DIRS`). `kreadconfig6` always includes
the system-wide default, so `kirk-set-theme` reads the account's own files to see what it chose.

**`kirk-theme-check`** (no sudo) prints an account's theme settings next to kirkus's, whether Plasma
can see the kirkus themes, which login steps have run, and the recent `kirkus-theme` log. Ask for
its output when someone's desktop doesn't look like kirkus.

**Previews.** Each Global Theme's `contents/previews/fullscreenpreview.jpg` (1920×1080) and
`preview.png` (600×337) are real screenshots of a fresh kirkus account in that theme, with Dolphin
at Home and Konsole showing `fastfetch`, so the preview is exactly what you get. Retake them if the
look changes. The login screen and splash previews are drawn by `make-screens.py` from the same
images and numbers the real screens use.

## Startup splash (after login)

The Plasma splash, `org.kirkus.splash`, uses the same logo in the same place. When you log in, the
password field disappears and the logo stays until the desktop appears. It's the default for every
account via `/etc/xdg/ksplashrc`; change it in System Settings → Colors & Themes → Splash Screen. The same
package is the kirkus Global Theme (see "Desktop theme").

## Other defaults

- zram swap with zstd, capped at 4 GB
- PipeWire audio
- A firewall (ufw): incoming connections blocked, outgoing allowed, KDE Connect (ports 1714–1764)
  let through. `kirk-firewall-setup.service` turns it on once, at the first start after installing or
  after the update that added it, and leaves `/var/lib/kirk-firewall-setup` so it never overrides
  you afterwards. Switch it on or off in System Settings → Firewall (`plasma-firewall`).
- `power-profiles-daemon`, which integrates with Plasma's battery controls
- Discover with Flatpak and Flathub set up, for installing and updating apps
