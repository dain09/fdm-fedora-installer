#!/usr/bin/env bash
set -e

# Use sudo only if not running as root
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

echo "==> [1/5] Installing dependencies..."
$SUDO dnf install -y binutils curl desktop-file-utils xdg-utils gnome-shell-extension-appindicator libappindicator-gtk3

echo "==> [2/5] Downloading and extracting Free Download Manager..."
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

curl -L -o fdm.deb "https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb"
ar x fdm.deb
$SUDO tar -xf data.tar.* -C /
$SUDO chmod +x /opt/freedownloadmanager/fdm /opt/freedownloadmanager/wenativehost 2>/dev/null || true

if command -v update-desktop-database >/dev/null 2>&1; then
    $SUDO update-desktop-database || true
fi
rm -rf "$TMP_DIR"

echo "==> [3/5] Setting up Native Messaging Hosts..."
# Chromium-based paths
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

# Firefox path
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

echo "==> [4/5] Associating torrent and magnet MIME types..."
xdg-mime default freedownloadmanager.desktop application/x-bittorrent 2>/dev/null || true
xdg-mime default freedownloadmanager.desktop x-scheme-handler/magnet 2>/dev/null || true

echo "==> [5/5] Removing conflicting Flatpak version if present..."
flatpak uninstall -y org.freedownloadmanager.Manager 2>/dev/null || true

echo "--------------------------------------------------------"
echo "Installation complete! Please restart your browser and session."