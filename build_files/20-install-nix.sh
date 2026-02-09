#!/usr/bin/env bash
set -euo pipefail

echo "::group:: Install Nix (Fedora Package)"

# Copy custom systemd units and scripts
rsync -arvKl /ctx/system_files/nix/ /
chmod +x /usr/bin/mount-nix.sh

# Create persistent store directory (content copied after dnf install)
install -d /var/lib/nix-store

# Install official Fedora Nix package (2.31.3, CVE-fixed)
dnf install -y nix nix-daemon

# Move Fedora's /nix content to persistent location
# This will be bind-mounted back at runtime
if compgen -G "/nix/*" >/dev/null; then
    echo "Moving /nix content to /var/lib/nix-store..."
    rsync -aH /nix/ /var/lib/nix-store/
    rm -rf /nix/*
fi

# Build and install SELinux policy (Fedora's nix package doesn't include one)
echo "Building SELinux policy for Nix..."
dnf install -y selinux-policy-devel
cp /ctx/build_files/selinux/nix.te /ctx/build_files/selinux/nix.fc /tmp/
pushd /tmp
checkmodule -M -m -o nix.mod nix.te
semodule_package -o nix.pp -m nix.mod -f nix.fc
install -D -m 644 nix.pp /usr/share/selinux/packages/nix.pp

# Precompute CIL hash so nix-selinux.service can skip loading if already installed
/usr/libexec/selinux/hll/pp nix.pp | sha256sum | cut -d' ' -f1 \
    | install -D -m 644 /dev/stdin /usr/share/nix/selinux-cil.sha256
popd

# Clean up selinux-policy-devel artifacts
rm -rf /var/lib/sepolgen


# Add drop-in to ensure nix-daemon.socket waits for our mount
mkdir -p /usr/lib/systemd/system/nix-daemon.socket.d
cat > /usr/lib/systemd/system/nix-daemon.socket.d/10-after-mount.conf << 'EOF'
[Unit]
After=nix-mount.service
Requires=nix-mount.service
EOF

# Enable services
systemctl enable nix-mount.service nix-daemon.socket nix-selinux.service

echo "::endgroup::"
