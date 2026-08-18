#!/usr/bin/env bash
set -e

# Use sudo only if not running as root
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

echo "==> Removing Free Download Manager..."

# Remove system files with root permissions
$SUDO rm -rf /opt/freedownloadmanager
$SUDO rm -f /usr/share/applications/freedownloadmanager.desktop
$SUDO find /etc -name "*freedownloadmanager*.json" -delete 2>/dev/null || true

# Remove user configuration files in HOME
find "$HOME/.config" "$HOME/.mozilla" -name "*freedownloadmanager*.json" -delete 2>/dev/null || true

# Run update-desktop-database safely if available
if command -v update-desktop-database >/dev/null 2>&1; then
    $SUDO update-desktop-database || true
fi

echo "FDM removed cleanly."
