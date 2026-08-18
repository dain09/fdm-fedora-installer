#!/usr/bin/env bash
set -e

echo "==> [1/4] Downloading and extracting Free Download Manager (.deb)..."
# Ensure binutils (ar) and curl are installed
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

echo "==> [2/4] Configuring Browser Native Messaging Hosts..."
# Target paths for Chromium-based browsers (Brave, Chrome, Chromium)
HOST_DIRS=(
    "$HOME/.config/BraveSoftware/Brave-Origin/NativeMessagingHosts"
    "$HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
    "$HOME/.config/google-chrome/NativeMessagingHosts"
    "$HOME/.config/chromium/NativeMessagingHosts"
)

JSON_CONTENT='{
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
    echo "$JSON_CONTENT" > "$DIR/org.freedownloadmanager.fdm5.cnh.json"
    chmod 644 "$DIR/org.freedownloadmanager.fdm5.cnh.json"
done

echo "==> [3/4] Installing GNOME System Tray (AppIndicator) support..."
sudo dnf install -y gnome-shell-extension-appindicator libappindicator-gtk3

echo "==> [4/4] Removing conflicting Flatpak version if present..."
flatpak uninstall -y org.freedownloadmanager.Manager 2>/dev/null || true

echo "--------------------------------------------------------"
echo "Installation completed successfully!"
echo "Please log out and log back in to enable the top bar tray icon."