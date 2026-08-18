#!/usr/bin/env bash
set -e

# 1. Architecture Check
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo "Error: Free Download Manager is only available for x86_64 architectures (found: $ARCH)."
    exit 1
fi

# 2. Determine root privileges and actual user home
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

echo "==> [1/5] Installing system dependencies..."
$SUDO dnf install -y binutils curl desktop-file-utils xdg-utils gnome-shell-extension-appindicator libappindicator-gtk3

echo "==> [2/5] Downloading and extracting FDM (.deb)..."
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
cd "$TMP_DIR"

curl -L -o fdm.deb "https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb"
ar x fdm.deb
$SUDO tar -xf data.tar.* -C /
$SUDO chmod +x /opt/freedownloadmanager/fdm /opt/freedownloadmanager/wenativehost 2>/dev/null || true

if command -v update-desktop-database >/dev/null 2>&1; then
    $SUDO update-desktop-database || true
fi

echo "==> [3/5] Setting up Native Messaging Hosts..."
# Chromium Manifest
HOST_DIRS=(
    "$USER_HOME/.config/BraveSoftware/Brave-Origin/NativeMessagingHosts"
    "$USER_HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
    "$USER_HOME/.config/google-chrome/NativeMessagingHosts"
    "$USER_HOME/.config/chromium/NativeMessagingHosts"
)

CHROMIUM_JSON='{
  "name": "org.freedownloadmanager.fdm5.cnh",
  "description": "Free Download Manager",
  "path": "/opt/freedownloadmanager/wenativehost",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://ahmpjcflkgiildlgicmcieglgoilbfdp/",
    "chrome-extension://mdfcjfioplkdchnhcpcobaheocanedjg/"
  ]
}'

for DIR in "${HOST_DIRS[@]}"; do
    mkdir -p "$DIR"
    echo "$CHROMIUM_JSON" > "$DIR/org.freedownloadmanager.fdm5.cnh.json"
    chmod 644 "$DIR/org.freedownloadmanager.fdm5.cnh.json"
done

# Firefox Manifest
FIREFOX_DIR="$USER_HOME/.mozilla/native-messaging-hosts"
mkdir -p "$FIREFOX_DIR"
cat << 'EOF' > "$FIREFOX_DIR/org.freedownloadmanager.fdm5.cnh.json"
{
  "name": "org.freedownloadmanager.fdm5.cnh",
  "description": "Free Download Manager",
  "path": "/opt/freedownloadmanager/wenativehost",
  "type": "stdio",
  "allowed_extensions": [
    "fdm_ffext@freedownloadmanager.org"
  ]
}
EOF
chmod 644 "$FIREFOX_DIR/org.freedownloadmanager.fdm5.cnh.json"

# Fix permissions for non-root target directories if run via sudo
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config" "$USER_HOME/.mozilla" 2>/dev/null || true
fi

echo "==> [4/5] Registering MIME associations..."
xdg-mime default freedownloadmanager.desktop application/x-bittorrent 2>/dev/null || true
xdg-mime default freedownloadmanager.desktop x-scheme-handler/magnet 2>/dev/null || true

echo "==> [5/5] Removing conflicting Flatpak version..."
flatpak uninstall -y org.freedownloadmanager.Manager 2>/dev/null || true

echo "--------------------------------------------------------"
echo "Installation complete! Restart your browser to activate."