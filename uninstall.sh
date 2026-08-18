#!/usr/bin/env bash
set -e

echo "==> Removing Free Download Manager..."
sudo rm -rf /opt/freedownloadmanager
sudo rm -f /usr/share/applications/freedownloadmanager.desktop
find "$HOME/.config" /etc "$HOME/.mozilla" -name "*freedownloadmanager*.json" -delete 2>/dev/null || true

# Run update-desktop-database safely if available
if command -v update-desktop-database >/dev/null 2>&1; then
    sudo update-desktop-database || true
fi

echo "Free Download Manager and all integration manifests have been removed."
