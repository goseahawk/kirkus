#!/usr/bin/env bash
# Build kirkus on a NON-Arch host (Fedora, Debian/Ubuntu, macOS, Windows+WSL2).
#
# Put this file next to build.sh in the project folder and run:   ./build-docker.sh
#
# The entire Arch build happens inside a throwaway privileged container; only the finished
# ISO is copied back out to ./out/. Nothing on your host is modified except that folder.
#
# Written to run under bash 3.2 (the /bin/bash that ships with macOS), so no associative arrays,
# no ${var,,}, and no expansion of a possibly-empty array under `set -u`.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
IMAGE=docker.io/library/archlinux:latest

[ -f "$HERE/build.sh" ] || {
  echo "build.sh not found next to this script."
  echo "Put build-docker.sh inside the project folder (the one containing build.sh and overlay/)."
  exit 1
}

# ---- pick a container engine ----
if command -v podman >/dev/null 2>&1; then
  ENGINE=podman
elif command -v docker >/dev/null 2>&1; then
  ENGINE=docker
else
  cat <<'MSG'
Neither podman nor docker was found. Install one:
  macOS:    brew install --cask docker        (or: brew install podman && podman machine init && podman machine start)
  Fedora:   sudo dnf install podman
  Debian:   sudo apt install podman           (or docker.io)
  Windows:  Docker Desktop with the WSL2 backend; run this script from inside WSL
MSG
  exit 1
fi
echo "Using $ENGINE (bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]})."

INTERACTIVE=no
if [ -t 0 ] && [ -t 1 ]; then INTERACTIVE=yes; fi

# ---- build the engine's argument list ----
# This array always has at least one element, so expanding it is safe under `set -u` even on
# bash 3.2. (An earlier version kept the --platform flag in its own array, which was empty on
# x86_64 hosts and made bash 3.2 abort with "PLATFORM[@]: unbound variable".)
RUN_ARGS="run --rm --privileged"
# -it needs a terminal; without one, podman/docker refuse to start.
if [ "$INTERACTIVE" = yes ]; then RUN_ARGS="$RUN_ARGS -it"; fi

# ---- architecture check ----
# mkarchiso runs x86_64 binaries. On ARM (Apple Silicon) every one of them is emulated.
HOSTARCH=$(uname -m)
case "$HOSTARCH" in
  x86_64|amd64) ;;
  *)
    cat <<MSG

WARNING: this machine reports '$HOSTARCH', not x86_64 (an Apple Silicon Mac, for example).
The ISO is x86_64, so the whole build would run under emulation: expect it to take hours,
and package scripts may fail outright. An x86_64 machine or a small cloud VM is a far better
build host.

MSG
    if [ "$INTERACTIVE" = yes ]; then
      printf 'Try anyway? [y/N] '
      read -r reply
      case "${reply:-n}" in
        y|Y|yes|YES) ;;
        *) exit 1 ;;
      esac
    else
      echo "Not running interactively, so continuing. Ctrl+C to stop."
    fi
    RUN_ARGS="$RUN_ARGS --platform linux/amd64"
    ;;
esac

# ---- rootless podman note (Linux only) ----
# mkarchiso has to mount filesystems and run pacstrap as root. Rootless podman maps root inside
# the container to your own user on the host, which can still fail at the chroot/mount step. On
# macOS and Windows the CLI talks to a Linux VM where it is already root, so sudo is wrong there.
NEEDS_SUDO_HINT=no
if [ "$ENGINE" = podman ] && [ "$(uname -s)" = Linux ] && [ "$(id -u)" -ne 0 ]; then
  NEEDS_SUDO_HINT=yes
fi

echo "Note: the build needs about 15-20 GB of free space in your $ENGINE storage."
mkdir -p "$HERE/out"

# The build tree lives INSIDE the container. Bind-mounting a macOS or Windows folder as the work
# directory breaks the file ownership, permissions and xattrs that mkarchiso depends on, so the
# project is mounted read-only and copied in, and only the ISO is written back out.
set +e
# shellcheck disable=SC2086  # RUN_ARGS is a deliberate list of whitespace-free flags
"$ENGINE" $RUN_ARGS \
  -e KIRK_VERSION="${KIRK_VERSION:-$(date +%y.%m.%d)}" \
  -v "$HERE:/src:ro" \
  -v "$HERE/out:/out" \
  "$IMAGE" bash -euo pipefail -c '
    echo "== updating the container and installing archiso =="
    pacman -Syu --noconfirm archiso git

    echo "== copying the project in =="
    mkdir -p /work
    cp -a /src/. /work/
    rm -rf /work/build /work/out      # never reuse a half-finished build tree
    cd /work

    ./build.sh

    echo "== copying the ISO out =="
    cp -v /work/out/*.iso /out/
    chmod 0644 /out/*.iso
  '
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
  echo
  echo "The build failed (exit $RC)."
  if [ "$NEEDS_SUDO_HINT" = yes ]; then
    cat <<'MSG'
If the error mentioned "failed to setup chroot", "permission denied" on /proc, or a mount
failure, that is rootless podman. mkarchiso needs real root. Retry with:

    sudo ./build-docker.sh
MSG
  fi
  echo "Otherwise, scroll up: the last pacman or mkarchiso error is the real one."
  exit "$RC"
fi

# If this ran under sudo, hand the ISO back to the user who invoked it rather than leaving it
# owned by root.
if [ -n "${SUDO_USER:-}" ] && [ "$(id -u)" -eq 0 ]; then
  chown -R "$SUDO_USER" "$HERE/out" 2>/dev/null || true
fi

cat <<MSG

Done. The ISO is in $HERE/out/

Write it to a USB stick:
  Linux:    sudo dd if=out/kirkus-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
  macOS:    diskutil list                       # find the USB, e.g. /dev/disk4
            diskutil unmountDisk /dev/disk4
            sudo dd if=out/kirkus-*.iso of=/dev/rdisk4 bs=4m status=progress
  Windows:  Rufus or balenaEtcher, written in DD / image mode
MSG
