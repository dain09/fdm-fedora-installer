#!/usr/bin/env bash
set -e

# Terminal Colors
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    CYAN=''
    BOLD=''
    NC=''
fi

info() { echo -e "${CYAN}==>${NC} ${BOLD}$1${NC}"; }
success() { echo -e "${GREEN}==>${NC} ${BOLD}$1${NC}"; }
error() { echo -e "${RED}Error:${NC} $1"; }

show_help() {
    cat << EOF
Free Download Manager (FDM) Updater for Fedora Linux

Usage:
  ./update.sh [options]

Options:
  -h, --help       Show this help message and exit

Description:
  Downloads and updates Free Download Manager binaries in-place
  without overwriting browser manifests or existing user configurations.
EOF
    exit 0
}

case "${1:-}" in
    -h|--help)
        show_help
        ;;
esac

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

info "Updating Free Download Manager to the latest version..."
if command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y binutils curl desktop-file-utils
fi

# Gracefully terminate running FDM instances before updating
pkill -x fdm 2>/dev/null || true

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
cd "$TMP_DIR" || exit 1

# Download the official deb package with retry
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

# Ensure HiDPI & Wayland CLI wrapper exists
cat << 'EOF' > "$TMP_DIR/fdm_cli"
#!/usr/bin/env bash
export QT_AUTO_SCREEN_SCALE_FACTOR=1
exec /opt/freedownloadmanager/fdm "$@"
EOF
$SUDO cp "$TMP_DIR/fdm_cli" /usr/local/bin/fdm
$SUDO chmod 755 /usr/local/bin/fdm

# Run update-desktop-database safely if available
if command -v update-desktop-database >/dev/null 2>&1; then
    $SUDO update-desktop-database || true
fi

success "Free Download Manager updated successfully!"
