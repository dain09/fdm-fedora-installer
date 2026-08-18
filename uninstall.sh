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
error() { echo -e "${RED}Error:${NC} $1"; }

show_help() {
    cat << EOF
Free Download Manager (FDM) Uninstaller for Fedora Linux

Usage:
  ./uninstall.sh [options]

Options:
  -h, --help       Show this help message and exit
  -y, --yes        Automatic yes to prompts (non-interactive mode)

Description:
  Completely removes Free Download Manager binaries (/opt/freedownloadmanager),
  desktop entry, CLI wrapper (/usr/local/bin/fdm), and all browser Native Messaging manifests.
EOF
    exit 0
}

AUTO_CONFIRM=false

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            show_help
            ;;
        -y|--yes|-f|--force)
            AUTO_CONFIRM=true
            ;;
    esac
done

# Interactive confirmation prompt if running in interactive terminal
if [ "$AUTO_CONFIRM" != "true" ] && [ -t 0 ]; then
    echo -ne "${YELLOW}Are you sure you want to completely remove Free Download Manager? [y/N]: ${NC}"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            ;;
        *)
            echo "Uninstallation cancelled."
            exit 0
            ;;
    esac
fi

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

# Gracefully terminate running FDM instances before removal
pkill -x fdm 2>/dev/null || true

info "Removing Free Download Manager..."
$SUDO rm -rf /opt/freedownloadmanager
$SUDO rm -f /usr/share/applications/freedownloadmanager.desktop
$SUDO rm -f /usr/local/bin/fdm
$SUDO rm -f /usr/lib64/mozilla/native-messaging-hosts/org.freedownloadmanager.fdm5.cnh.json /usr/lib/mozilla/native-messaging-hosts/org.freedownloadmanager.fdm5.cnh.json 2>/dev/null || true
$SUDO find /etc -name "*freedownloadmanager*.json" -delete 2>/dev/null || true

find "$USER_HOME/.config" "$USER_HOME/.mozilla" "$USER_HOME/.librewolf" "$USER_HOME/.floorp" "$USER_HOME/.waterfox" "$USER_HOME/.var/app/org.mozilla.firefox" -name "*freedownloadmanager*.json" -delete 2>/dev/null || true
rm -f "$USER_HOME/.var/app/org.mozilla.firefox/.mozilla/native-messaging-hosts/fdm_flatpak_bridge.sh" 2>/dev/null || true

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

success "Free Download Manager has been completely removed."
