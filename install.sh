#!/usr/bin/env bash
set -e

# Terminal Colors
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    YELLOW='\033[1;33m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    CYAN=''
    YELLOW=''
    BOLD=''
    NC=''
fi

info() { echo -e "${CYAN}==>${NC} ${BOLD}$1${NC}"; }
success() { echo -e "${GREEN}==>${NC} ${BOLD}$1${NC}"; }
warn() { echo -e "${YELLOW}Warning:${NC} $1"; }
error() { echo -e "${RED}Error:${NC} $1"; }

show_help() {
    cat << EOF
Free Download Manager (FDM) Native Installer for Fedora Linux

Usage:
  ./install.sh [options]

Options:
  -h, --help       Show this help message and exit

Description:
  Installs Free Download Manager native binaries directly to /opt/freedownloadmanager,
  configures browser Native Messaging Hosts across Chromium and Firefox browsers,
  registers MIME handlers for torrent/magnet links, and sets up GNOME tray integration.
EOF
    exit 0
}

case "${1:-}" in
    -h|--help)
        show_help
        ;;
esac

# 1. Architecture Check
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    error "Free Download Manager is only available for x86_64 architectures (found: $ARCH)."
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

# 3. Check for package manager (Fedora Workstation vs Fedora Atomic/Silverblue)
info "[1/6] Installing system dependencies..."
if command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y binutils curl desktop-file-utils xdg-utils gnome-shell-extension-appindicator libappindicator-gtk3
elif command -v rpm-ostree >/dev/null 2>&1; then
    info "Fedora Atomic (Silverblue/Kinoite/Bazzite) detected."
    warn "Ensure required dependencies are layered with rpm-ostree if not already installed."
else
    warn "Neither dnf nor rpm-ostree found. Proceeding with extraction..."
fi

# Gracefully terminate running FDM instances before extraction
pkill -x fdm 2>/dev/null || true

info "[2/6] Downloading and extracting FDM (.deb)..."
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
cd "$TMP_DIR" || exit 1

curl -L --retry 3 --retry-delay 2 -o fdm.deb "https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb"
ar x fdm.deb
$SUDO tar -xf data.tar.* -C /
$SUDO chmod +x /opt/freedownloadmanager/fdm /opt/freedownloadmanager/wenativehost 2>/dev/null || true

# Create symlink in PATH
$SUDO ln -sf /opt/freedownloadmanager/fdm /usr/local/bin/fdm

if command -v update-desktop-database >/dev/null 2>&1; then
    $SUDO update-desktop-database || true
fi

info "[3/6] Setting up Native Messaging Hosts..."
# Chromium-based Manifests
CHROMIUM_HOST_DIRS=(
    "$USER_HOME/.config/BraveSoftware/Brave-Origin/NativeMessagingHosts"
    "$USER_HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
    "$USER_HOME/.config/google-chrome/NativeMessagingHosts"
    "$USER_HOME/.config/chromium/NativeMessagingHosts"
    "$USER_HOME/.config/microsoft-edge/NativeMessagingHosts"
    "$USER_HOME/.config/microsoft-edge-dev/NativeMessagingHosts"
    "$USER_HOME/.config/vivaldi/NativeMessagingHosts"
    "$USER_HOME/.config/opera/NativeMessagingHosts"
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

for DIR in "${CHROMIUM_HOST_DIRS[@]}"; do
    mkdir -p "$DIR"
    echo "$CHROMIUM_JSON" > "$DIR/org.freedownloadmanager.fdm5.cnh.json"
    chmod 644 "$DIR/org.freedownloadmanager.fdm5.cnh.json"
done

# Firefox-based Manifests (Firefox, LibreWolf, Floorp, Waterfox)
FIREFOX_HOST_DIRS=(
    "$USER_HOME/.mozilla/native-messaging-hosts"
    "$USER_HOME/.librewolf/native-messaging-hosts"
    "$USER_HOME/.floorp/native-messaging-hosts"
    "$USER_HOME/.waterfox/native-messaging-hosts"
)

FIREFOX_JSON='{
  "name": "org.freedownloadmanager.fdm5.cnh",
  "description": "Free Download Manager",
  "path": "/opt/freedownloadmanager/wenativehost",
  "type": "stdio",
  "allowed_extensions": [
    "fdm_ffext@freedownloadmanager.org"
  ]
}'

for DIR in "${FIREFOX_HOST_DIRS[@]}"; do
    mkdir -p "$DIR"
    echo "$FIREFOX_JSON" > "$DIR/org.freedownloadmanager.fdm5.cnh.json"
    chmod 644 "$DIR/org.freedownloadmanager.fdm5.cnh.json"
done

# Fix permissions for non-root target directories if run via sudo
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.config" "$USER_HOME/.mozilla" "$USER_HOME/.librewolf" "$USER_HOME/.floorp" "$USER_HOME/.waterfox" 2>/dev/null || true
fi

info "[4/6] Registering MIME associations..."
xdg-mime default freedownloadmanager.desktop application/x-bittorrent 2>/dev/null || true
xdg-mime default freedownloadmanager.desktop x-scheme-handler/magnet 2>/dev/null || true

info "[5/6] Removing conflicting Flatpak version if present..."
if command -v flatpak >/dev/null 2>&1; then
    flatpak uninstall -y org.freedownloadmanager.Manager 2>/dev/null || true
fi

info "[6/6] Finalizing setup..."
echo "--------------------------------------------------------"
success "Free Download Manager has been installed successfully!"
echo -e "You can launch it from your applications menu or type '${BOLD}fdm${NC}' in your terminal."
echo -e "Please restart your browser to activate the extension."