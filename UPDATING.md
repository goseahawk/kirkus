# Updating kirkus

There are three kinds of updates, each with its own tool:

| What | How | How often |
|---|---|---|
| The Arch Linux system underneath (kernel, Plasma, drivers, apps installed with pacman) | `sudo pacman -Syu` | about once a week |
| The kirkus release (branding, boot and login screens, About page, hardware support) | `sudo ./apply-to-installed.sh` | when a new kirkus release comes out |
| Flatpak apps | Discover → **Updates** | whenever Discover says updates are available |

If you do more than one at a time, go in that order: system first, then kirkus, then Flatpak apps.

## 1. The Arch system: `sudo pacman -Syu`

kirkus is Arch Linux underneath, so almost everything on your computer comes from Arch's packages and
is updated with pacman. Open Konsole and run:

    sudo pacman -Syu

This downloads the latest package lists (`-y`) and upgrades every installed package (`-u`). Read what
it lists and type `Y` to go ahead.

- **Snapshots happen on their own.** On Btrfs (the default filesystem), a Timeshift snapshot is taken
  automatically just before important packages are upgraded: the kernel, systemd, GRUB, graphics
  drivers, Plasma, and the Broadcom Wi-Fi driver.
- **Restart after kernel or Plasma updates.** If the list included `linux`, `systemd` or Plasma
  packages, restart when it finishes.
- **Upgrade everything at once.** Don't run `pacman -Sy` followed by installing a single package, and
  don't skip `-u`. Arch only supports upgrading all packages together; upgrading half of them can break
  programs.
- **Check the news first** if you haven't updated in a while: <https://archlinux.org/news/>. Now and
  then an update needs a manual step, and it's announced there.
- **The Broadcom Wi-Fi driver** (on Macs and PCs that need it) is rebuilt automatically for each new
  kernel. That's why the update can pause for a minute on `dkms`. Let it finish.

### If an update breaks something

1. Restart and tap **Esc** while the kirkus logo is on screen (you have 2 seconds) to show the GRUB
   menu.
2. Open **kirkus YY.MM.DD snapshots** and pick the snapshot from just before the update. The computer
   starts from it, and any changes you make while it's running are temporary.
3. Once it starts, open **Timeshift**, select the same snapshot and click **Restore** to make it
   permanent, then restart.

## 2. The kirkus release: `apply-to-installed.sh`

`pacman -Syu` doesn't update kirkus's own files. Those come from this project, so a new kirkus release
is applied with its script. First get the latest version of the project.

**If you cloned it with git:**

    cd ~/kirkus
    git pull

**If you haven't got it yet:**

    git clone https://github.com/goseahawk/kirkus.git ~/kirkus
    cd ~/kirkus

(Or download it from GitHub with **Code → Download ZIP** and extract it.)

Then, from the project folder:

    sudo ./apply-to-installed.sh

This updates the name and version, the boot splash, GRUB theme, login screen, Plasma splash,
wallpaper, icon, fastfetch logo, About This Computer page and hardware support, without reinstalling.
On Btrfs it takes a snapshot before changing anything that affects starting up. It doesn't touch your
files or apps, the EFI partition or the way your computer boots, and it's safe to run more than once. Restart when it finishes.

To see which kirkus version you have, open **System Settings → About this System**, or run:

    cat /etc/kirk-release

## 3. Flatpak apps: Discover

Apps installed from **Discover** come from Flathub as Flatpaks, and Discover keeps them up to date:

1. Open **Discover**.
2. Click **Updates** at the bottom left.
3. Click **Update All**.

Discover also shows a notification in the system tray when Flatpak updates are available.

Discover only manages Flatpak apps on kirkus. System packages aren't shown there, so it won't run
`pacman -Syu` for you. Use Konsole for that (section 1).

From the terminal, the same Flatpak update is:

    flatpak update
