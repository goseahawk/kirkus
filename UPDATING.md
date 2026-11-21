# Updating kirkus

**kirkus updates itself every week.** Once a week, when you're plugged in and not on a metered
connection, it updates the Arch system and your Flatpak apps, and new kirkus releases follow. On Btrfs a
snapshot is taken first, and a notification tells you when it's done (and whether to restart).

| What | Automatically | By hand |
|---|---|---|
| The Arch Linux system underneath (kernel, Plasma, drivers, apps installed with pacman) | weekly | `sudo pacman -Syu` |
| The kirkus release (branding, boot and login screens, About page, hardware support) | after every system update | `sudo kirk-update` |
| Flatpak apps | weekly | Discover → **Updates** |

## Automatic weekly updates

A timer checks a few times a day and updates once 7 days have passed since the last full update,
whether that was automatic or one you ran yourself. It waits, and tries again later, if you're on
battery, on a metered connection, or offline.

**When Arch posts news, you're asked to update by hand.** Now and then an Arch update needs a manual
step, and it's announced at <https://archlinux.org/news/>. If there's news since your last update,
kirkus doesn't update on its own; a notification asks you to read the news and run
`sudo pacman -Syu` yourself. After that, weekly updates carry on.

**To turn automatic updates off** (or back on), open **System Settings → System Update**, or run:

    sudo kirk-auto-update off      # or: on
    kirk-auto-update status        # on or off, and when you last updated
    sudo kirk-auto-update now      # update right now
    journalctl -u kirk-auto-update # what the automatic updates did

With them off, update with `sudo pacman -Syu` about once a week.

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
- **The Broadcom Wi-Fi driver** (on Intel Macs and PCs that need it) is rebuilt automatically for each new
  kernel. That's why the update can pause for a minute on `dkms`. Let it finish.

### If an update breaks something

1. Restart and tap **Esc** while the kirkus logo is on screen (you have 2 seconds) to show the GRUB
   menu.
2. Open **kirkus YY.MM.DD snapshots** and pick the snapshot from just before the update. The computer
   starts from it, and any changes you make while it's running are temporary.
3. Once it starts, open **Timeshift**, select the same snapshot and click **Restore** to make it
   permanent, then restart.

## 2. The kirkus release: automatic

kirkus's own files (branding, boot and login screens, About page, hardware support) don't come from
Arch's packages. They're updated by kirkus itself, and it happens on its own: whenever
`sudo pacman -Syu` upgrades something, kirkus checks GitHub for a newer published release once pacman
has finished. If there is one, it downloads that release and applies it in the background, and a
notification tells you to restart when it's done.

- Only **published releases** are installed, never unfinished work.
- It never goes backwards to an older release.
- If you're offline, it skips the check and tries again after the next upgrade.

Useful commands:

    sudo kirk-update --check     # is there a newer release?
    sudo kirk-update             # check and install it now
    sudo kirk-update --main      # install the newest changes on GitHub, even unreleased ones
    journalctl -u kirk-update    # what the automatic updates did

`--main` applies whatever is on GitHub's main branch right now, so you get changes before they're
released. Your version becomes today's date, and `grep SOURCE /etc/kirk-release` shows which commit
you're on. Later releases still install as normal once they're newer than that.

**To turn automatic updates off**, edit `/etc/kirk-update.conf` and set `AUTO_UPDATE=no`. Updates
won't change that setting. You can still update with `sudo kirk-update`.

### Updating by hand from the project folder

You can also apply a copy of the project directly, for example one you've changed yourself. (To get
the newest changes from GitHub, `sudo kirk-update --main` is simpler.) First get the project.

**If you cloned it with git:**

    cd ~/kirkus
    git pull

**If you haven't got it yet:**

    git clone https://github.com/goseahawk/kirkus.git ~/kirkus
    cd ~/kirkus

(Or download it from GitHub with **Code → Download ZIP** and extract it.)

Then, from the project folder:

    sudo ./apply-to-installed.sh

Like the automatic update, this updates the name and version, the boot splash, GRUB theme, login screen, Plasma splash,
wallpaper, icon, fastfetch logo, About This Computer page and hardware support, without reinstalling.
On Btrfs it takes a snapshot before changing anything that affects starting up. It doesn't touch your
files or apps, the EFI partition or the way your computer boots, and it's safe to run more than once. Restart when it finishes.

To see which kirkus version you have, open **System Settings → About this System**, or run:

    cat /etc/kirk-release

## 3. Flatpak apps: Discover

Apps installed from **Discover** come from Flathub as Flatpaks, and Discover keeps them up to date:

1. Open **Discover** (or **System Settings → Flatpak Update**, which opens it on the Updates page).
2. Click **Updates** at the bottom left.
3. Click **Update All**.

Discover also shows a notification in the system tray when Flatpak updates are available.

Discover only manages Flatpak apps on kirkus. System packages aren't shown there, so it won't run
`pacman -Syu` for you. Use Konsole for that (section 1).

From the terminal, the same Flatpak update is:

    flatpak update
