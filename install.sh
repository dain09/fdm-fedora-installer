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

# Chromium-based Manifest Paths
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

# Firefox-based Manifest Paths
FIREFOX_HOST_DIRS=(
    "$USER_HOME/.mozilla/native-messaging-hosts"
    "$USER_HOME/.librewolf/native-messaging-hosts"
    "$USER_HOME/.floorp/native-messaging-hosts"
    "$USER_HOME/.waterfox/native-messaging-hosts"
)

show_help() {
    cat << EOF
Free Download Manager (FDM) Native Installer for Fedora Linux

Usage:
  ./install.sh [options] [path/to/fdm.deb]

Options:
  -h, --help       Show this help message and exit
  -d, --doctor     Run system diagnostic report and verify installation health

Arguments:
  [path/to/fdm.deb] Optional local debian package file to install offline

Description:
  Installs Free Download Manager native binaries directly to /opt/freedownloadmanager,
  configures browser Native Messaging Hosts across Chromium and Firefox browsers,
  registers MIME handlers for torrent/magnet links, and sets up GNOME tray integration.
EOF
    exit 0
}

run_doctor() {
    echo -e "${BOLD}========================================================${NC}"
    echo -e "${BOLD}   Free Download Manager (FDM) - System Doctor Report   ${NC}"
    echo -e "${BOLD}========================================================${NC}"
    echo ""

    # 1. Core Binaries
    echo -e "${CYAN}[Core Binaries]${NC}"
    if [ -f /opt/freedownloadmanager/fdm ] && [ -x /opt/freedownloadmanager/fdm ]; then
        echo -e "  ${GREEN}[✓]${NC} FDM binary: /opt/freedownloadmanager/fdm"
    else
        echo -e "  ${RED}[✗]${NC} FDM binary missing or not executable"
    fi

    if [ -f /opt/freedownloadmanager/wenativehost ] && [ -x /opt/freedownloadmanager/wenativehost ]; then
        echo -e "  ${GREEN}[✓]${NC} Native messaging host: /opt/freedownloadmanager/wenativehost"
    else
        echo -e "  ${RED}[✗]${NC} Native messaging host missing or not executable"
    fi

    if [ -f /usr/local/bin/fdm ] && [ -x /usr/local/bin/fdm ]; then
        echo -e "  ${GREEN}[✓]${NC} CLI Command wrapper: /usr/local/bin/fdm"
    else
        echo -e "  ${YELLOW}[-]${NC} CLI Command wrapper not installed"
    fi
    echo ""

    # 2. Desktop & MIME
    echo -e "${CYAN}[Desktop & MIME Integration]${NC}"
    if [ -f /usr/share/applications/freedownloadmanager.desktop ]; then
        echo -e "  ${GREEN}[✓]${NC} Desktop launcher: /usr/share/applications/freedownloadmanager.desktop"
    else
        echo -e "  ${RED}[✗]${NC} Desktop launcher missing"
    fi

    TORRENT_HANDLER=$(xdg-mime query default application/x-bittorrent 2>/dev/null || true)
    if [[ "$TORRENT_HANDLER" =~ freedownloadmanager ]]; then
        echo -e "  ${GREEN}[✓]${NC} Torrent MIME handler: $TORRENT_HANDLER"
    else
        echo -e "  ${YELLOW}[-]${NC} Torrent MIME handler: ${TORRENT_HANDLER:-None}"
    fi

    MAGNET_HANDLER=$(xdg-mime query default x-scheme-handler/magnet 2>/dev/null || true)
    if [[ "$MAGNET_HANDLER" =~ freedownloadmanager ]]; then
        echo -e "  ${GREEN}[✓]${NC} Magnet MIME handler: $MAGNET_HANDLER"
    else
        echo -e "  ${YELLOW}[-]${NC} Magnet MIME handler: ${MAGNET_HANDLER:-None}"
    fi
    echo ""

    # 3. Browser Manifests
    echo -e "${CYAN}[Browser Native Messaging Manifests]${NC}"
    for DIR in "${CHROMIUM_HOST_DIRS[@]}"; do
        BROWSER_NAME=$(basename "$(dirname "$DIR")")
        if [ -f "$DIR/org.freedownloadmanager.fdm5.cnh.json" ]; then
            echo -e "  ${GREEN}[✓]${NC} $BROWSER_NAME: configured"
        else
            echo -e "  ${YELLOW}[-]${NC} $BROWSER_NAME: not present"
        fi
    done

    for DIR in "${FIREFOX_HOST_DIRS[@]}"; do
        BROWSER_NAME=$(basename "$(dirname "$DIR")")
        if [ -f "$DIR/org.freedownloadmanager.fdm5.cnh.json" ]; then
            echo -e "  ${GREEN}[✓]${NC} $BROWSER_NAME: configured"
        else
            echo -e "  ${YELLOW}[-]${NC} $BROWSER_NAME: not present"
        fi
    done
    echo ""

    # 4. GNOME Tray
    echo -e "${CYAN}[GNOME Tray (AppIndicator) Support]${NC}"
    if rpm -q gnome-shell-extension-appindicator >/dev/null 2>&1; then
        echo -e "  ${GREEN}[✓]${NC} gnome-shell-extension-appindicator package is installed"
    else
        echo -e "  ${YELLOW}[-]${NC} gnome-shell-extension-appindicator package not installed"
    fi
    echo ""
    exit 0
}

LOCAL_DEB=""
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            show_help
            ;;
        -d|--doctor|--status|--check)
            run_doctor
            ;;
        *.deb)
            if [ -f "$arg" ]; then
                LOCAL_DEB=$(realpath "$arg")
            else
                error "Specified local package '$arg' not found."
                exit 1
            fi
            ;;
    esac
done

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

info "[2/6] Extracting Free Download Manager package..."
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
cd "$TMP_DIR" || exit 1

if [ -n "$LOCAL_DEB" ]; then
    info "Using local deb package: $LOCAL_DEB"
    cp "$LOCAL_DEB" fdm.deb
else
    curl -L --retry 3 --retry-delay 2 -o fdm.deb "https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb"
fi

# Verify archive integrity
if ! ar t fdm.deb >/dev/null 2>&1; then
    error "Downloaded package is corrupted or incomplete. Please check your internet connection and retry."
    exit 1
fi

ar x fdm.deb
$SUDO tar -xf data.tar.* -C /
$SUDO chmod +x /opt/freedownloadmanager/fdm /opt/freedownloadmanager/wenativehost 2>/dev/null || true

# Create HiDPI & Wayland compatible CLI wrapper in PATH
cat << 'EOF' > "$TMP_DIR/fdm_cli"
#!/usr/bin/env bash
export QT_AUTO_SCREEN_SCALE_FACTOR=1
exec /opt/freedownloadmanager/fdm "$@"
EOF
$SUDO cp "$TMP_DIR/fdm_cli" /usr/local/bin/fdm
$SUDO chmod 755 /usr/local/bin/fdm

# Refresh desktop database and icon caches
if command -v update-desktop-database >/dev/null 2>&1; then
    $SUDO update-desktop-database || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    $SUDO gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi

info "[3/6] Setting up Native Messaging Hosts..."
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