# Keeping kirkus up to date

**You don't have to do anything.** Once a week kirkus updates itself: the system, your apps from
Discover, and kirkus's own features and look. When it's done, a notification tells you, and whether
you need to restart.

## What happens each week

- kirkus waits until you're **plugged in** and **not on a metered connection** (like a phone
  hotspot), so it won't drain your battery or your data. If you're offline, it tries again later.
- With the default Btrfs filesystem, it takes a **snapshot** first, so you can go back if something
  goes wrong (see "If an update breaks something").
- It updates the system, then your Flatpak apps (the apps you install from Discover). New versions of
  kirkus itself follow right after.
- If you updated by hand recently, it waits until a full week has passed since then.

## When kirkus asks you to update yourself

Now and then an Arch Linux update needs a small manual step, and Arch announces it on its news page.
When that happens, kirkus doesn't update on its own. Instead you get a notification saying updates
are waiting for you. Then:

1. Read the newest posts at [archlinux.org/news](https://archlinux.org/news/). Most only matter if you
   use the software they mention.
2. Follow any steps the post gives you.
3. Open **Konsole** and run `sudo pacman -Syu` (see "Updating right now"). After that, weekly updates
   carry on by themselves.

## Updating right now

**Everything:** open **Konsole** (from the app menu) and run:

    sudo pacman -Syu

Enter your password, read the list of updates it shows, and type `Y` to go ahead. New versions of
kirkus itself are checked for automatically once it finishes.

- If the list includes `linux`, `systemd` or Plasma, **restart** when it finishes.
- It can pause for a minute on a step called `dkms`. That's a Wi-Fi driver being rebuilt for the new
  system version. Let it finish.
- **Always update everything at once** with `sudo pacman -Syu`. Installing a single updated package
  on its own can break other programs on Arch.

**Just your apps:** open System Settings → **Flatpak Update** (or Discover → **Updates**), then
click **Update All**. Discover handles apps only; system updates aren't shown there.

**Just kirkus itself:** run `sudo kirk-update`.

## Turning automatic updates off

Open System Settings → **System Update** and choose "Don't update automatically". You'll be asked for
your password. Turn it back on the same way.

With automatic updates off, run `sudo pacman -Syu` yourself about once a week. Arch changes quickly,
and updating rarely makes each update bigger and more likely to need attention.

New versions of kirkus itself still arrive after each `sudo pacman -Syu`. To stop that too, open
`/etc/kirk-update.conf` as administrator (for example `sudo nano /etc/kirk-update.conf`) and change
`AUTO_UPDATE=yes` to `AUTO_UPDATE=no`.

## If an update breaks something

With the default Btrfs filesystem, you can go back to how things were before the update:

1. Restart, and tap **Esc** while the kirkus logo is on screen to show the boot menu.
2. Choose the **snapshots** entry, then the snapshot from just before the update. Your computer
   starts as it was then. Changes you make while it's running are temporary.
3. If everything works, open the **Timeshift** app, select that snapshot and click **Restore** to
   make it permanent. Then restart.

## Which version do I have?

System Settings → **About this System** shows it, for example *kirkus 26.11.18*. Versions are the date
they were made, so a higher number is newer.

## Commands, for the curious

| Command | What it does |
|---|---|
| `kirk-auto-update status` | whether weekly updates are on, and when you last updated |
| `sudo kirk-auto-update now` | run the weekly update right now |
| `sudo kirk-auto-update off` / `on` | the same as the System Update switch |
| `sudo kirk-update --check` | is there a newer version of kirkus? |
| `sudo kirk-update` | install it |
| `sudo kirk-update --main` | install the very newest kirkus changes, even ones not released yet |
| `journalctl -u kirk-auto-update` | what the weekly updates did |
| `journalctl -u kirk-update` | what the kirkus updates did |
