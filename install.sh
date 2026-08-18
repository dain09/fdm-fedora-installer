#!/usr/bin/env bash
set -e

echo "==> [1/6] Installing core dependencies..."
# Ensure required tools are installed
sudo dnf install -y binutils curl desktop-file-utils

echo "==> [2/6] Downloading and extracting Free Download Manager (.deb)..."
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

echo "==> [3/6] Configuring Browser Native Messaging Hosts (Chromium & Firefox)..."
# 1. Chromium-based Browsers (Brave, Chrome, Chromium)
HOST_DIRS=(
    "$HOME/.config/BraveSoftware/Brave-Origin/NativeMessagingHosts"
    "$HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
    "$HOME/.config/google-chrome/NativeMessagingHosts"
    "$HOME/.config/chromium/NativeMessagingHosts"
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

# 2. Mozilla Firefox
FIREFOX_DIR="$HOME/.mozilla/native-messaging-hosts"
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

echo "==> [4/6] Installing GNOME System Tray (AppIndicator) support..."
sudo dnf install -y gnome-shell-extension-appindicator libappindicator-gtk3

echo "==> [5/6] Removing conflicting Flatpak version if present..."
flatpak uninstall -y org.freedownloadmanager.Manager 2>/dev/null || true

echo "==> [6/6] Registering MIME associations (Torrents & Magnet links)..."
xdg-mime default freedownloadmanager.desktop application/x-bittorrent 2>/dev/null || true
xdg-mime default freedownloadmanager.desktop x-scheme-handler/magnet 2>/dev/null || true

echo "--------------------------------------------------------"
echo "Installation completed successfully!"
echo "Please log out and log back in to enable the top bar tray icon."