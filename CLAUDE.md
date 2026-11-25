# kirkus: notes for Claude

kirkus is a simple, easy-to-use Arch Linux distribution with KDE Plasma, built with archiso. It
installs from a live USB (start screen + text installer), detects hardware (including Intel Macs),
and keeps itself updated. Public repo: github.com/goseahawk/kirkus. How it works inside is in
`DEVELOPMENT.md`; read that before changing anything.

## Working with the owner

- The owner usually wants each change committed and pushed to `main` when it's done, with a clear
  commit message. Commits use the owner's GitHub noreply address. Never put the owner's personal
  email address in the repo, commits or anything sent to an outside service.
- For appearance and branding changes (logo, colours, splash, login screen, wallpaper, themes), keep
  commit messages vague, e.g. "Update branding" or "Appearance tweaks". Don't describe the details.
- Keep replies short and plain: what changed, anything to watch out for, and what the owner needs to
  do (usually: publish a release, or run `sudo kirk-update --main` on the computer).
- For visual changes (logo, splash, login screen), render previews and offer a few options to choose
  from before applying.
- The owner's own computer is a 2015 MacBook Air (Broadcom `wl` Wi-Fi). It boots kirkus through
  `bless` from macOS Recovery.

## Docs

- `README.md` and `UPDATING.md` are for **users**: plain steps, no internals, no maintainer notes.
  Don't add lines about small internal features.
- `DEVELOPMENT.md` is for maintainers: internals, the release process and the project layout.
- License stays the last section of the README, after "Building the ISO yourself".

## Rules that matter

- **Versions** are `YY.MM.DD`, or `YY.MM.DD.N` for later builds the same day. Release tags are the
  bare version (no `v`). `kirk-update` compares versions with `sort -V`.
- **Published releases go to every installed system automatically** (after its next `pacman -Syu`).
  Test with a draft release or "Just build" in the Build ISO workflow first.
- `apply-to-installed.sh` copies the whole `overlay/installed` tree (files in its `KEEP` list, like
  `/etc/kirk-update.conf`, are only installed when missing). It has no migration code for old names;
  keep it that way.
- New programs in the live ISO (`overlay/airootfs/usr/local/bin`) need an entry in `build.sh`'s
  `file_permissions`, or archiso makes them non-executable.
- System Settings entries are `.desktop` files in
  `overlay/installed/usr/share/plasma/systemsettings/externalmodules/` (plus a copy in
  `usr/share/applications/`). Discover's "Software Update" page is hidden in `/etc/xdg/kdeglobals`.

## Branding

- The mark is a vulture (the bird) with a Marigold head. The logo files are in `branding/build/`:
  `logo.svg` (lockup on light), `logo-dark.svg` (on dark), `logo-one-color.svg`, `icon.svg` (app
  icon: the bird on a Marigold rounded square), `mark.svg` (one-colour bird), `mark-color.svg` and
  `mark-dark.svg` (the bird cut out of the two lockups). The wordmark is DM Sans Bold, always
  lowercase; DM Sans is bundled in `overlay/installed/usr/share/fonts/kirkus/`.
- `branding/tools/make-screens.py` builds every screen image, the wallpaper and the app icon from
  those files; `make-fastfetch-logo.py` and `make-live-icons.py` do the rest. Rerun them after any
  logo change, and check that the login and splash bird are pixel-identical.
- Every screen is Ink and centres its image at `x = W/2`, `y = H/2 - 50`, with even image sizes:
  GRUB background = the bird; boot splash (Plymouth) = the word "kirkus", fading in; login screen
  (SDDM) = the bird at 30% opacity; Plasma splash = the same bird brightening from 30% to full.
- Palette: Ink `#16171b`, Bone `#f3efe6`, Marigold `#f2a93b`. Text on Marigold is Ink.

## Testing

There's no way to boot kirkus from here, so:

- Syntax-check every script (`bash -n`, `sh -n`, `python3 -m py_compile`) and validate XML/JSON.
- Test scripts against mocks of the commands they call (pacman, nmcli, gdbus, curl, kdialog), with
  paths redirected to a temporary folder, covering each case.
- Say clearly what has only been tested that way.

Not yet confirmed on real hardware: tap to click and the first-login
touchpad question, and weekly automatic updates.
