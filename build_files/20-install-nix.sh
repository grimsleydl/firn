#!/usr/bin/env bash
set -euo pipefail

echo "::group:: Install Nix"
rpm_url="https://nix-community.github.io/nix-installers/nix/x86_64/nix-multi-user-2.24.10.rpm"

rsync -arvKl /ctx/system_files/nix/ /

install -d /usr/share/nix-store /nix

# Avoid systemd calls during RPM %post in the image build environment.
export SYSTEMD_OFFLINE=1

# Pre-create this so the %post scriptlet skips the /root setup block.
# /root is a symlink to var/roothome on ostree systems, so create the real target.
mkdir -p /var/roothome/.nix-defexpr

# Install the RPM; allow missing GPG key since we fetch directly by URL.
dnf install -y --nogpgcheck "$rpm_url"

# Clean up the workaround directory.
rm -rf /var/roothome/.nix-defexpr
# Clean up nix channels
rm -rf /var/roothome/.nix-channels
rm -rf /var/roothome/.nix-profile

# Move the pre-populated store out of /nix so it can serve as the immutable lowerdir.
if compgen -G "/nix/*" >/dev/null; then
  mv /nix/* /usr/share/nix-store/
fi

# The RPM %post handles sysusers/tmpfiles; if we ran with SYSTEMD_OFFLINE the
# post scripts are still executed, so no extra calls are needed here.

systemctl enable nix-overlay.service
echo "::endgroup::"
