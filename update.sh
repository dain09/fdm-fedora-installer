#!/usr/bin/env bash
set -e

echo "==> Updating Free Download Manager to the latest version..."
# Ensure required tools
sudo dnf install -y binutils curl

TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

# Download the official deb package
curl -L -o fdm.deb "https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb"

# Extract package and install to system root
ar x fdm.deb
sudo tar -xf data.tar.* -C /
sudo update-desktop-database
rm -rf "$TMP_DIR"

echo "Free Download Manager updated successfully!"
