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
Free Download Manager (FDM) Updater for Fedora Linux

Usage:
  ./update.sh [options]

Options:
  -h, --help       Show this help message and exit
  -f, --force      Force update / re-download even if already up to date
  -c, --check      Check for updates without downloading or installing

Description:
  Checks upstream Free Download Manager releases. If a newer version is available,
  it downloads and updates binaries in-place without overwriting user configs.
EOF
    exit 0
}

FORCE_UPDATE=false
CHECK_ONLY=false

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            show_help
            ;;
        -f|--force)
            FORCE_UPDATE=true
            ;;
        -c|--check)
            CHECK_ONLY=true
            ;;
    esac
done

# Architecture Check
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    error "Free Download Manager is only available for x86_64 architectures (found: $ARCH)."
    exit 1
fi

# Determine root privileges
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

# Get current installed version
if [ -f /opt/freedownloadmanager/.version ]; then
    CURRENT_VERSION=$(cat /opt/freedownloadmanager/.version | tr -d '[:space:]')
elif [ -f /opt/freedownloadmanager/fdm ]; then
    CURRENT_VERSION="unknown"
else
    error "Free Download Manager is not installed. Please run ./install.sh first."
    exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
cd "$TMP_DIR" || exit 1

info "Checking for upstream updates..."

# Probe the first ~300KB to read the control archive version without downloading 40MB
REMOTE_VERSION=""
if curl -sL --retry 3 --retry-delay 2 -r 0-300000 -o "$TMP_DIR/fdm_probe.deb" "https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb"; then
    if ar t "$TMP_DIR/fdm_probe.deb" >/dev/null 2>&1; then
        CONTROL_TAR=$(ar t "$TMP_DIR/fdm_probe.deb" | grep "control.tar" | head -n 1 || true)
        if [ -n "$CONTROL_TAR" ]; then
            ar p "$TMP_DIR/fdm_probe.deb" "$CONTROL_TAR" > "$TMP_DIR/$CONTROL_TAR" 2>/dev/null || true
            REMOTE_VERSION=$(tar -xaf "$TMP_DIR/$CONTROL_TAR" -O ./control 2>/dev/null | grep -i '^Version:' | awk '{print $2}' || true)
        fi
    fi
fi

if [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" != "unknown" ]; then
    echo -e "  Installed version : ${BOLD}v${CURRENT_VERSION}${NC}"
else
    echo -e "  Installed version : ${YELLOW}unknown${NC}"
fi

if [ -n "$REMOTE_VERSION" ]; then
    echo -e "  Latest version    : ${BOLD}v${REMOTE_VERSION}${NC}"
else
    warn "Could not determine remote version string. Proceeding with update check."
fi

# Check if already up to date
if [ "$FORCE_UPDATE" != "true" ] && [ -n "$REMOTE_VERSION" ] && [ "$CURRENT_VERSION" = "$REMOTE_VERSION" ]; then
    echo ""
    success "Free Download Manager is already up to date! (v${CURRENT_VERSION})"
    echo -e "To force re-download, run: ${BOLD}./update.sh --force${NC}"
    exit 0
fi

if [ "$CHECK_ONLY" = "true" ]; then
    echo ""
    if [ "$CURRENT_VERSION" != "$REMOTE_VERSION" ]; then
        info "A new update is available: v${REMOTE_VERSION}"
    else
        success "FDM is currently up to date."
    fi
    exit 0
fi

echo ""
info "Downloading Free Download Manager update (v${REMOTE_VERSION:-latest})..."

if command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y binutils curl desktop-file-utils bubblewrap libxcb libxkbcommon-x11 >/dev/null 2>&1 || true
fi

# Gracefully terminate running FDM instances before updating
pkill -x fdm 2>/dev/null || true

# Download the full official deb package with retry
curl -L --retry 3 --retry-delay 2 -o fdm.deb "https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb"

# Verify archive integrity
if ! ar t fdm.deb >/dev/null 2>&1; then
    error "Downloaded package is corrupted or incomplete. Please check your internet connection and retry."
    exit 1
fi

# Extract package and install to system root
ar x fdm.deb
$SUDO tar -xf data.tar.* -C /
$SUDO chmod +x /opt/freedownloadmanager/fdm /opt/freedownloadmanager/wenativehost 2>/dev/null || true

# Save updated version metadata
if [ -n "$REMOTE_VERSION" ]; then
    echo "$REMOTE_VERSION" | $SUDO tee /opt/freedownloadmanager/.version >/dev/null
fi

# Ensure HiDPI & Wayland CLI wrapper exists
cat << 'EOF' > "$TMP_DIR/fdm_cli"
#!/usr/bin/env bash
export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
exec /opt/freedownloadmanager/fdm "$@"
EOF
$SUDO cp "$TMP_DIR/fdm_cli" /usr/local/bin/fdm
$SUDO chmod 755 /usr/local/bin/fdm

# Install High-Resolution Icons
if [ -f /opt/freedownloadmanager/icon.png ]; then
    $SUDO mkdir -p /usr/share/icons/hicolor/128x128/apps /usr/share/pixmaps 2>/dev/null || true
    $SUDO cp /opt/freedownloadmanager/icon.png /usr/share/icons/hicolor/128x128/apps/freedownloadmanager.png
    $SUDO cp /opt/freedownloadmanager/icon.png /usr/share/pixmaps/freedownloadmanager.png
fi

# Refresh desktop launcher
cat << 'EOF' > "$TMP_DIR/freedownloadmanager.desktop"
[Desktop Entry]
Name=Free Download Manager
GenericName=Download Manager
Comment=Fast, modern download accelerator and BitTorrent client
Keywords=download;manager;accelerator;torrent;magnet;p2p;fdm;
Exec=/usr/local/bin/fdm %U
Terminal=false
Type=Application
Icon=freedownloadmanager
Categories=Network;FileTransfer;P2P;Qt;
StartupNotify=true
StartupWMClass=fdm
MimeType=application/x-bittorrent;x-scheme-handler/magnet;
EOF
$SUDO cp "$TMP_DIR/freedownloadmanager.desktop" /usr/share/applications/freedownloadmanager.desktop
$SUDO chmod 644 /usr/share/applications/freedownloadmanager.desktop

# Run update-desktop-database and icon cache refresh safely if available
if command -v update-desktop-database >/dev/null 2>&1; then
    $SUDO update-desktop-database || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    $SUDO gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi
if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental 2>/dev/null || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
    kbuildsycoca5 --noincremental 2>/dev/null || true
fi

success "Free Download Manager updated successfully to v${REMOTE_VERSION:-latest}!"
