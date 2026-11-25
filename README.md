# kirkus

**kirkus is a simple, easy-to-use Arch Linux system.** Arch is fast, up to date and flexible, but
setting it up yourself takes a lot of decisions and a lot of time on the command line. kirkus makes
those decisions for you, so you get a complete, good-looking KDE Plasma desktop that just works.

- **Easy to install.** A start screen and a guided installer that asks a few questions.
- **Your hardware is set up for you.** Wi-Fi, graphics and CPU drivers, and Mac-specific fixes, are
  detected and installed automatically.
- **Mistakes can be undone.** Snapshots are taken before risky updates, and you can start your
  computer from one right from the boot menu.
- **Updates take care of themselves.** Every week kirkus updates the system, your apps and itself.

It's still Arch underneath, so nothing is hidden or locked down: pacman, the AUR and the
[Arch wiki](https://wiki.archlinux.org/) all work as usual whenever you want to go further.

kirkus is an independent project **based on Arch Linux**. It is not affiliated with or endorsed by
Arch Linux.

## What you need

- A **64-bit Intel or AMD PC**, or an **Intel Mac**. Apple Silicon Macs (M1 and later) aren't
  supported.
- At least **15 GB** of free disk space (30 GB or more is comfortable), and 4 GB of memory or more.
- A **USB stick** of 4 GB or more. Everything on it will be erased.
- An **internet connection** while installing.

## 1. Download kirkus and make a USB stick

1. Go to the **[kirkus website](https://goseahawk.github.io/kirkus/)** and click **Download**. (Or get
   the newest `kirkus-YY.MM.DD-x86_64.iso` from
   [Releases](https://github.com/goseahawk/kirkus/releases/latest), plus the `.sha256` file next to
   it.)
2. Optional, but a good idea: check that the download isn't damaged. In a terminal, in the folder you
   downloaded both files to, run `sha256sum -c kirkus-*.iso.sha256` (on a Mac:
   `shasum -a 256 -c kirkus-*.iso.sha256`). It should say `OK`.
3. Write the ISO to the USB stick with [balenaEtcher](https://etcher.balena.io/) (Windows, macOS or
   Linux): pick the ISO, pick the USB stick, click Flash.

## 2. Make room for kirkus

The installer can do this three ways. Decide which before you start, and **back up anything
important** first.

- **Use the whole disk.** The simplest. Everything on that disk is erased.
- **Keep Windows or macOS alongside it (dual boot).** First make some free space from the other
  system. kirkus installs into that free space and leaves the rest alone.
  - **Windows:** open Disk Management, right-click your main partition, choose Shrink Volume, and
    shrink it by at least 15 GB.
  - **macOS:** update macOS fully first (this also updates the Mac's firmware). Then in Disk Utility,
    choose your disk, click Partition and make the macOS part smaller.
- **Use a partition you've already made.** For people who like to set up their disk themselves. That
  partition is erased.

## 3. Install

1. **Start from the USB stick.**
   - **On a PC:** plug it in and turn the computer on while pressing its boot menu key. That's often
     F12, F11, F8 or Esc, and it's usually shown briefly at power-on. Choose the USB stick.
   - **On a Mac:** plug it in, turn the Mac on while holding **Option (⌥)**, and choose **EFI Boot**.
2. **A start screen opens.** Click **Connect to Wi-Fi**, choose "Activate a connection", pick your
   network and enter its password, then choose Back and Quit. (With a network cable plugged in,
   you're already connected.)
3. Click **Install kirkus**. The installer asks, one at a time:
   - **your keyboard**, picked from a list
   - **how to install:** 1 for the whole disk, 2 for free space beside another system, 3 for a
     partition (see step 2)
   - **which disk**, picked from a list that shows each disk's size and what's on it. (With 3, you
     pick the partition instead.)
   - **a name for the computer, your username and a password**
   - **your time zone** and **language setting**. It suggests both, so you can usually just press
     Enter. For the time zone you can also type a city, such as `London`.

   If an answer doesn't work, it tells you why and asks again. At the end it shows a summary, and
   nothing is changed until you type `yes`. Installing usually takes 10 to 30 minutes, depending on
   your internet connection.
4. When it says it's finished, click **Restart** at the bottom of the start screen and remove the USB
   stick.

If the start screen doesn't appear, you'll see text instructions instead: type `nmtui` to connect to
Wi-Fi, then `./install.sh` to install.

## 4. Starting kirkus

After a short black screen with the kirkus logo, you'll see the login screen. Log in with the
password you chose.

- **On a PC with another system:** if your computer starts the other system instead, open its boot
  menu (the same key as in step 3) and choose **kirkus**, or move kirkus to the top of the boot order
  in your computer's firmware settings.
- **On a Mac:** hold **Option (⌥)** when you turn it on to choose between macOS and kirkus (shown as
  "EFI Boot"). If it isn't listed, see "Troubleshooting".
- **The boot menu is hidden.** To see it (for example to start from a snapshot), tap **Esc** while
  the kirkus logo is on screen at power-on.

## 5. First steps

- **Touchpad:** on a laptop you're asked once whether to keep tap to click. You can change it later in
  System Settings → Mouse & Touchpad.
- **Apps:** install apps from **Discover**, in the app menu.
- **Light or dark:** kirkus starts dark. For the light version, open System Settings → **Global
  Theme** and choose **kirkus Light**, or turn on **Switch to Dark Mode at Night** to have both.
- **Firewall:** on from the start. It blocks other computers from connecting in, without getting in
  the way of anything you do. Change it in System Settings → **Firewall**.
- **Your computer's details:** System Settings → **About this System** shows the model, battery
  health, storage and when kirkus was installed.
- **Mac webcam:** to use the FaceTime HD camera, open Konsole and run `facetimehd-setup` once.

## Updates

kirkus updates itself once a week: the system, your Flatpak apps and kirkus itself. It waits until
you're plugged in and not on a metered connection, and a notification tells you when it's done and
whether to restart.

- **To turn this off:** System Settings → **System Update**.
- **To update Flatpak apps right now:** System Settings → **Flatpak Update**, or Discover → Updates.
- **To update the system right now:** open Konsole and run `sudo pacman -Syu`.

If Arch announces something that needs your attention, kirkus doesn't update on its own. A
notification asks you to read the news at [archlinux.org/news](https://archlinux.org/news/) and then
run `sudo pacman -Syu` yourself.

See [UPDATING.md](UPDATING.md) for the details.

## Undoing a bad update

With the default Btrfs filesystem, kirkus keeps **snapshots** of the system: one right after
installing, daily and weekly ones, and one just before any important update. They cover the system,
not your personal files in your home folder (you can add those in Timeshift → Settings → Users).

If something stops working after an update:

1. Restart, and tap **Esc** while the kirkus logo is on screen to show the boot menu.
2. Choose the **snapshots** entry, then the snapshot from just before the update. Your computer starts
   as it was then. Changes you make while it's running are temporary.
3. If everything works, open the **Timeshift** app, select that snapshot and click **Restore** to
   make it permanent. Then restart.

Snapshots are stored on the same disk, so they protect against a bad update, not a broken disk. Keep
real backups of your files.

## Troubleshooting

**My Mac doesn't show kirkus when I hold Option.** Start macOS Recovery (hold Cmd+R at power-on),
open Utilities → Terminal, and run:

    diskutil mount disk0s1
    bless --mount /Volumes/EFI --setBoot --nextonly --shortform --file /Volumes/EFI/EFI/BOOT/BOOTX64.EFI

Restart. That starts kirkus once. If it works, run the same commands without `--nextonly` to make
kirkus start by default. (Hold Option at power-on to choose macOS instead.)

**My touchpad's click is stuck or broken.** Tap to click instead. To stop a stuck click from getting
in the way, open System Settings → **Touchpad Clicks** and choose to ignore physical clicks.

**The login screen is blank.** Press Ctrl+Alt+F2, log in with your username and password, and run
`sudo kirk-login-theme breeze` and then `sudo systemctl restart sddm`. That switches to KDE's
standard login screen.

**I want to see what's happening while it starts.** Press Esc while the kirkus logo is on screen.

**Wi-Fi doesn't work.** Run `kirk-detect --summary` in Konsole to see which Wi-Fi chip kirkus found.
Please [open an issue](https://github.com/goseahawk/kirkus/issues) with the result.

## Building the ISO yourself

Most people should just download the ISO from Releases. To build your own, for example with your
own changes:

- **On Arch:** `sudo ./build.sh` (it installs `archiso` if you don't have it).
- **On any other OS** (Fedora, Debian, macOS, Windows with WSL2): `./build-docker.sh`. It needs Docker
  or Podman on an x86_64 computer, and runs the whole Arch build in a throwaway container.

The ISO lands in `out/`, named for today's date (set `KIRK_VERSION=26.11.18` to choose
the version). Expect 30–60 minutes. See [DEVELOPMENT.md](DEVELOPMENT.md) for how kirkus is put
together.

## License

The code is under the MIT License (see `LICENSE`). The kirkus logo and the files in `branding/` are
**not** covered by it; they may not be reused without permission. Arch Linux is a trademark of its
respective owners.
