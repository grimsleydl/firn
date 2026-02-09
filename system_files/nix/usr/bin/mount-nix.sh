#!/usr/bin/env bash
set -euo pipefail

# Bind-mount /var/lib/nix-store to /nix
# This provides a writable, persistent store on bootc/ostree systems

# Already mounted? Skip.
if mountpoint -q /nix; then
    exit 0
fi

mkdir -p /var/lib/nix-store
mount --bind /var/lib/nix-store /nix
mount -o remount,bind,exec /nix

# Ensure required directory structure exists
mkdir -p /nix/store /nix/var/nix/daemon-socket

# Restore SELinux contexts on critical directories (not recursive into store)
# This is fast and ensures socket creation and store writes work
if command -v restorecon >/dev/null 2>&1; then
    restorecon /nix /nix/store /nix/var /nix/var/nix /nix/var/nix/daemon-socket
fi
