#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
    USER_HOME="$HOME"
else
    SUDO=""
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        USER_HOME="$HOME"
    fi
fi

echo "==> Removing Free Download Manager..."
$SUDO rm -rf /opt/freedownloadmanager
$SUDO rm -f /usr/share/applications/freedownloadmanager.desktop
$SUDO rm -f /usr/local/bin/fdm
$SUDO find /etc -name "*freedownloadmanager*.json" -delete 2>/dev/null || true

find "$USER_HOME/.config" "$USER_HOME/.mozilla" -name "*freedownloadmanager*.json" -delete 2>/dev/null || true

if command -v update-desktop-database >/dev/null 2>&1; then
    $SUDO update-desktop-database || true
fi

echo "Free Download Manager has been completely removed."
