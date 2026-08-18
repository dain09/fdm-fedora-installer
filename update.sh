#!/usr/bin/env bash
set -e

# Architecture Check
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo "Error: Free Download Manager is only available for x86_64 architectures (found: $ARCH)."
    exit 1
fi

# Determine root privileges
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

echo "==> Updating Free Download Manager to the latest version..."
if command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y binutils curl desktop-file-utils
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
cd "$TMP_DIR"

# Download the official deb package with retry
curl -L --retry 3 --retry-delay 2 -o fdm.deb "https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb"

# Extract package and install to system root
ar x fdm.deb
$SUDO tar -xf data.tar.* -C /
$SUDO chmod +x /opt/freedownloadmanager/fdm /opt/freedownloadmanager/wenativehost 2>/dev/null || true

# Ensure symlink in PATH exists
$SUDO ln -sf /opt/freedownloadmanager/fdm /usr/local/bin/fdm

# Run update-desktop-database safely if available
if command -v update-desktop-database >/dev/null 2>&1; then
    $SUDO update-desktop-database || true
fi

echo "Free Download Manager updated successfully!"
