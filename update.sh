#!/usr/bin/env bash
set -e

echo "==> Updating Free Download Manager to the latest version..."
# Ensure required tools are installed
sudo dnf install -y binutils curl desktop-file-utils

TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

# Download the official deb package
curl -L -o fdm.deb "https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb"

# Extract package and install to system root
ar x fdm.deb
sudo tar -xf data.tar.* -C /

# Run update-desktop-database safely if available
if command -v update-desktop-database >/dev/null 2>&1; then
    sudo update-desktop-database || true
fi

rm -rf "$TMP_DIR"

echo "Free Download Manager updated successfully!"
