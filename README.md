# Kirk Arch Linux

Arch Linux with KDE Plasma, packaged as a bootable ISO with a text installer. Btrfs with Timeshift
snapshots, a consistent look from power-on to desktop, and hardware support that installs itself
when it's needed, including Intel Macs.

Kirk Arch Linux is an independent project **based on Arch Linux**. It is not affiliated with or
endorsed by Arch Linux.

- **Installs three ways:** erase a disk, use free space alongside macOS or Windows, or format a
  partition you prepared.
- **Btrfs + Timeshift** by default: snapshots before risky upgrades, bootable from the GRUB menu.
- **One look from boot to desktop:** GRUB, the boot splash, the login screen and the Plasma splash all
  draw the logo in the same place, so it never moves. Matching wallpaper, icon, fastfetch logo and an
  About This Computer page.
- **Hardware detection:** Mac fixes only on Macs, the Broadcom `wl` Wi-Fi driver only on chips
  that need it, and microcode and graphics drivers matched to your CPU and GPU.
- **Dated versions:** each build is named for the day it was built, e.g. *Kirk Arch Linux 26.11.18*.

## 1. Build the ISO

**On Arch:**

    sudo ./build.sh

**On any other OS (Fedora, Debian, macOS, Windows + WSL2):** needs Docker or Podman, on an x86_64
machine:

    ./build-docker.sh

The whole Arch build runs inside a throwaway privileged container; only the ISO comes back, in `out/`.
On Apple Silicon it would run under emulation and be impractically slow, so build on an x86_64
machine instead.

Write it to a USB stick:

    sudo dd if=out/kirk-arch-*.iso of=/dev/sdX bs=4M status=progress oflag=sync

macOS: `diskutil unmountDisk /dev/diskN` first, then write to `/dev/rdiskN` with `bs=4m`.
Windows: Rufus or balenaEtcher, in DD / image mode.

## 2. Pick an install style

**A. Erase a whole disk.** Simplest; everything on that disk is removed.

**B. Alongside another system (dual boot).** Make free space from the other system first. Linux
can't safely shrink macOS's APFS or Windows' BitLocker-encrypted NTFS:

- **macOS:** back up, and update macOS fully (that also updates the firmware). Then shrink it in Disk
  Utility → Partition, or in Terminal: `diskutil apfs resizeContainer disk1 100g`, which keeps 100 GB
  for macOS. Use `diskutil list` to find the container's name.
- **Windows:** back up, then Disk Management → right-click the main partition → Shrink Volume.

Then choose "Install in free space" in the installer. It reuses the existing EFI partition and makes
one Linux partition in the free space. It needs at least 15 GiB.

**C. A partition you prepared.** Choose "Install to an existing partition", give it that partition
(it's **formatted**) and the existing EFI partition.

## 3. Install

Boot the USB (on a Mac, hold Option at startup and pick "EFI Boot"), then:

    nmtui          # join Wi-Fi
    ./install.sh   # pick a mode, filesystem, user details, and go

It downloads packages, so it needs internet. The first thing it shows is what it detected about the
computer.

### Hardware detection

`kirk-detect` decides what to install, both on the live USB and in the installed system:

| Detected | What gets installed |
|---|---|
| Broadcom **BCM4331, BCM4352 or BCM4360** Wi-Fi (on any computer) | Broadcom's `wl` driver, with the open-source drivers that would grab the chip blocked. Other Broadcom chips, e.g. the BCM4350 in later MacBooks, keep Linux's built-in drivers, which `wl` would break. |
| An **Apple** computer | Mac support: the instant-wake-from-suspend fix, the Apple keyboard Fn setting, a FaceTime HD webcam helper, and a bootloader setup that never writes to the Mac's firmware settings (see below) |
| Intel / AMD **CPU** | `intel-ucode` + `thermald`, or `amd-ucode` |
| Intel / AMD **graphics** | `vulkan-intel` + `intel-media-driver`, or `vulkan-radeon` |

Run `kirk-detect --summary` to see what it finds. To override it, set `KIRK_IS_MAC=yes|no` or
`KIRK_BROADCOM_WL=yes|no` before running `./install.sh`. The results are recorded in
`/etc/kirk-release`.

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

## 4. Booting afterwards

**On a PC:** GRUB is installed the normal way, with a firmware boot entry called KirkArch. If another
system starts instead, pick KirkArch in your firmware's boot menu (often F12, F11 or Esc at power-on),
or move it to the top of the boot order in the firmware settings.

**On a Mac:** GRUB goes only at `EFI/BOOT/BOOTX64.EFI`, the path the Option-key startup manager
lists as "EFI Boot". The installer never writes boot entries to a Mac's firmware with `efibootmgr`,
which has been reported to damage Mac firmware, and never touches macOS's boot files. Hold Option at
startup to choose. If the startup manager doesn't list Linux, make it the default from macOS
Recovery (Cmd+R → Utilities → Terminal):

    diskutil mount disk0s1
    bless --mount /Volumes/EFI --setBoot --nextonly --shortform --file /Volumes/EFI/EFI/BOOT/BOOTX64.EFI

`--nextonly` tries it for one boot; run it again without `--nextonly` to keep it. `tools/` has a
read-only diagnosis script and a repair script for this situation.

### The GRUB menu is hidden

GRUB waits 2 seconds with the menu hidden, then boots. **Tap Esc** during that moment to show it (for
the fallback entry or the snapshots submenu). Use Esc rather than F4: on many laptop keyboards the
F-keys are media keys unless you hold Fn.

Those 2 seconds already show the boot splash, so the boot looks like one continuous screen. GRUB can't
do that on its own (its hidden countdown never draws a background), so `/etc/grub.d/06_kirk_splash`
draws the image and runs its own Esc-interruptible wait. If that script is removed or GRUB can't run
it, you get GRUB's normal hidden wait.

When the menu does show, it uses the splash as its background with the entries underneath. Theme files
are in `/boot/grub/themes/kirk-arch/`. `kirk-grub-theme-font` builds its font from Space Grotesk,
falling back to Noto Sans or GRUB's built-in font.

To change it, edit `GRUB_TIMEOUT` / `GRUB_TIMEOUT_STYLE` in `/etc/default/grub` (`menu` shows it every
time), then `sudo grub-mkconfig -o /boot/grub/grub.cfg`. Don't set the timeout to 0: the menu can
become unreachable.

## 5. Updating an installed system

Copy this project onto the installed computer and run, from its folder:

    sudo ./apply-to-installed.sh

It brings an existing install up to date with the current project (name and version, branding, splash
screens, login screen, fastfetch, About page, hardware support) without reinstalling. It never touches
the EFI partition or reinstalls GRUB, so the way the computer boots stays as it is. It also renames
files that earlier versions installed under other names, putting the new ones in place before removing
the old.

On a Mac, run `facetimehd-setup` once as your normal user to install the webcam driver from the AUR.

## Btrfs + Timeshift (default filesystem)

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

## Version

Each build is versioned by its date as **YY.MM.DD**, e.g. **Kirk Arch Linux 26.11.18**. The version
appears in the ISO's boot menu and filename (`kirk-arch-26.11.18-x86_64.iso`), the live USB's
welcome message, System Settings → About this System, fastfetch, the login banner and the GRUB menu.

- `build.sh` uses the date you build the ISO, and the installer passes it on in `/etc/kirk-release`.
  `apply-to-installed.sh` uses the date you run it. Override either with `KIRK_VERSION=26.11.18`.
- os-release gets `NAME="Kirk Arch Linux"`, `PRETTY_NAME="Kirk Arch Linux 26.11.18"`, `VERSION` and
  `VERSION_ID`. pacman resets os-release whenever the `filesystem` package updates, so a hook
  rebuilds it from `/etc/kirk-release`.
- **Never put an apostrophe in the name.** GRUB's config generators read it from `/etc/default/grub`
  and os-release, and an ASCII apostrophe produces a `grub.cfg` that fails `grub-script-check`.

## About This Computer

System Settings → **About this System** shows the logo and name with the usual CPU, memory,
graphics and Plasma details, plus four extra lines:

| Line | Source |
|---|---|
| Model | maker and model from the firmware, with friendly names for some Macs (e.g. `MacBookAir7,2` → "MacBook Air (13-inch, Early 2015 or 2017)") |
| Battery | health as % of design capacity, plus charge cycles when the firmware reports them |
| Storage | free / total on `/`, and whether it's Btrfs with snapshots |
| Installed | the install date from `/etc/kirk-release` |

The **About This Computer** entry in the app menu opens it directly. It's wired up by `LOGO=kirk-arch-logo`
in os-release and `/etc/xdg/kcm-about-distrorc`, which lists the `kirk-about-*` scripts.
KInfoCenter **refuses to open** if one of those scripts prints anything other than exactly two lines,
so keep that rule when editing them.

## Boot splash

A Plymouth theme, `kirk-arch`, shows the logo on black while the system starts, with the cream dot
breathing. Files: `/usr/share/plymouth/themes/kirk-arch/`.

- **See boot messages:** press Esc while the splash is up.
- **Change it:** edit `kirk-arch.script`, then `sudo plymouth-set-default-theme -R kirk-arch`.
- **Turn it off:** remove `splash` (and `quiet`, for full messages) from `GRUB_CMDLINE_LINUX_DEFAULT` in
  `/etc/default/grub`, then `sudo grub-mkconfig -o /boot/grub/grub.cfg`.
- If the theme fails to load, Plymouth falls back to text; it never stops the boot.

## Login screen

An SDDM theme, `kirk-arch`, continues the boot splash: the logo in the same place, the password field
under it, the date and time at the top, and the session plus Sleep / Restart / Shut Down along the
bottom. A wrong password shakes the field; Caps Lock gets a warning.

- **Preview without logging out:** `kirk-login-preview`.
- **Switch theme:** `sudo kirk-login-theme breeze`, and back with `sudo kirk-login-theme`. This also
  updates System Settings' own config, so the two always agree.
- **If the login screen is ever blank:** press Ctrl+Alt+F2, log in, run `sudo kirk-login-theme breeze`,
  then `sudo systemctl restart sddm`.

The lock screen (Super+L) belongs to Plasma, not SDDM, so it's unaffected.

## Startup splash (after login)

The Plasma splash, `org.kirkarch.splash`, uses the same logo in the same place. When you log in, the
password field disappears and the logo stays until the desktop appears. It's the default for every
account via `/etc/xdg/ksplashrc`; change it in System Settings → Colors & Themes → Splash Screen. Plasma
only loads splashes from "look-and-feel" packages, so it also appears in the Global Theme list. Keep
Breeze selected there.

## fastfetch

`fastfetch` shows the mark (blue K, cream dot) in Unicode half-blocks, with the labels in brand blue.
The default for everyone is `/etc/xdg/fastfetch/config.jsonc`; your own
`~/.config/fastfetch/config.jsonc` takes priority. `fastfetch -c kirk-arch` always uses it.

## Branding

Everything visual comes from the logo files in `branding/source/`. `branding/build/` holds what's
generated from them:

- `lockup.png`, `lockup-nodot.png`, `dot.png`: the lockup made transparent by separating it from its
  black background (accurate to 1/255), with the dot split out so it can breathe on its own.
- `screen-*.png`: the same at screen size. Every screen draws the lockup at
  `x = floor(W/2 - w/2), y = floor(H/2 - h/2) - 50`, so it's pixel-identical from GRUB to the desktop.
- `mark.svg`: the K and dot traced to vector outlines, from which the app icon (`kirk-arch-logo.svg`)
  and wallpaper (`kirk-arch-wallpaper.svg`) are built.

Palette: navy `#0b1020`, blue `#5590b4`, cream `#fff8ec`, slate `#aeb6c8`. The boot-to-desktop screens
are black; the wallpaper and icon tile are navy.

Typeface: **Space Grotesk** (SIL Open Font License), the wordmark's font, used on the login screen and
in the GRUB menu. It isn't in Arch's repos, so `kirk-install-fonts` downloads the official 2.0.0
release, checks its SHA-256 and installs it to `/usr/share/fonts/kirk-arch/`. If that fails, nothing
breaks; standard fonts are used instead.

## Other defaults

- zram swap with zstd, capped at 4 GB
- PipeWire audio
- `power-profiles-daemon`, which integrates with Plasma's battery controls

## Layout

| Path | What it is |
|---|---|
| `build.sh` | builds the ISO on Arch |
| `build-docker.sh` | builds the ISO on any other OS, in a container |
| `apply-to-installed.sh` | updates an existing install to the current project |
| `overlay/airootfs/` | files for the live USB: `install.sh`, `kirk-install-backend`, live Wi-Fi detection |
| `overlay/installed/` | files copied into every installed system (incl. `kirk-detect`) |
| `overlay/hardware/broadcom-wl/` | added only when a chip needs the `wl` driver |
| `overlay/hardware/mac/` | added only on Macs |
| `branding/` | logo sources and everything generated from them |
| `tools/` | Mac boot troubleshooting: a read-only diagnosis script and a repair script |

## License

The code is under the MIT License (see `LICENSE`). The Kirk Arch Linux logo and the files in
`branding/` are **not** covered by it; they may not be reused without permission. Arch Linux is a
trademark of its respective owners.
