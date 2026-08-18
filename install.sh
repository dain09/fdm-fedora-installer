#!/usr/bin/env bash
# Free Download Manager Native Installer for Fedora Linux
# An unofficial, community-maintained automation suite.
# Not affiliated with or endorsed by FreeDownloadManager.org or Softdeluxe.
# License: MIT (See LICENSE and DISCLAIMER.md)
set -e

# Terminal Colors & Styling
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    YELLOW='\033[1;33m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    CYAN=''
    YELLOW=''
    BOLD=''
    DIM=''
    NC=''
fi

info() { echo -e "${CYAN}==>${NC} ${BOLD}$1${NC}"; }
success() { echo -e "${GREEN}==>${NC} ${BOLD}$1${NC}"; }
warn() { echo -e "${YELLOW}Warning:${NC} $1"; }
error() { echo -e "${RED}Error:${NC} $1"; }

send_desktop_notification() {
    local title="$1"
    local msg="$2"
    local icon="${3:-freedownloadmanager}"

    # 1. Direct notify-send if running inside active graphical user session
    if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && command -v notify-send >/dev/null 2>&1; then
        notify-send -i "$icon" -a "Free Download Manager" "$title" "$msg" 2>/dev/null || true
        return 0
    fi

    # 2. If running under sudo or systemd service, dispatch to active logged-in graphical users
    if command -v notify-send >/dev/null 2>&1; then
        for user_dir in /run/user/*; do
            [ -d "$user_dir" ] || continue
            local uid
            uid=$(basename "$user_dir")
            [ "$uid" -ge 1000 ] 2>/dev/null || continue
            local uname
            uname=$(id -nu "$uid" 2>/dev/null || true)
            [ -n "$uname" ] || continue

            if [ -S "$user_dir/bus" ]; then
                sudo -u "$uname" DBUS_SESSION_BUS_ADDRESS="unix:path=$user_dir/bus" \
                    notify-send -i "$icon" -a "Free Download Manager" "$title" "$msg" 2>/dev/null || true
            fi
        done
    fi
}

show_banner() {
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
  _____ ____  __  __   _           _        _ _           
 |  ___|  _ \|  \/  | (_)_ __  ___| |_ __ _| | | ___ _ __ 
 | |_  | | | | |\/| | | | '_ \/ __| __/ _` | | |/ _ \ '__|
 |  _| | |_| | |  | | | | | | \__ \ || (_| | | |  __/ |   
 |_|   |____/|_|  |_| |_|_| |_|___/\__\__,_|_|_|\___|_|   
EOF
    echo -e "${NC}${CYAN} Native Free Download Manager Suite for Fedora Linux${NC}"
    echo -e "${DIM}------------------------------------------------------------${NC}"
}

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

# Native Chromium-based Manifest Paths (RPM / Tarball)
CHROMIUM_NATIVE_DIRS=(
    "$USER_HOME/.config/BraveSoftware/Brave-Origin/NativeMessagingHosts"
    "$USER_HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
    "$USER_HOME/.config/BraveSoftware/Brave-Browser-Beta/NativeMessagingHosts"
    "$USER_HOME/.config/BraveSoftware/Brave-Browser-Nightly/NativeMessagingHosts"
    "$USER_HOME/.config/google-chrome/NativeMessagingHosts"
    "$USER_HOME/.config/google-chrome-beta/NativeMessagingHosts"
    "$USER_HOME/.config/google-chrome-unstable/NativeMessagingHosts"
    "$USER_HOME/.config/chromium/NativeMessagingHosts"
    "$USER_HOME/.config/thorium/NativeMessagingHosts"
    "$USER_HOME/.config/microsoft-edge/NativeMessagingHosts"
    "$USER_HOME/.config/microsoft-edge-beta/NativeMessagingHosts"
    "$USER_HOME/.config/microsoft-edge-dev/NativeMessagingHosts"
    "$USER_HOME/.config/vivaldi/NativeMessagingHosts"
    "$USER_HOME/.config/vivaldi-snapshot/NativeMessagingHosts"
    "$USER_HOME/.config/opera/NativeMessagingHosts"
    "$USER_HOME/.config/opera-beta/NativeMessagingHosts"
    "$USER_HOME/.config/opera-developer/NativeMessagingHosts"
    "$USER_HOME/.config/opera-gx/NativeMessagingHosts"
)

# Native Firefox-based Manifest Paths (RPM / Tarball & Forks)
FIREFOX_NATIVE_DIRS=(
    "$USER_HOME/.mozilla/native-messaging-hosts"
    "$USER_HOME/.librewolf/native-messaging-hosts"
    "$USER_HOME/.floorp/native-messaging-hosts"
    "$USER_HOME/.waterfox/native-messaging-hosts"
    "$USER_HOME/.zen/native-messaging-hosts"
    "$USER_HOME/.mullvad/native-messaging-hosts"
    "$USER_HOME/.ghostery/native-messaging-hosts"
)

# Flatpak Browser App Definitions (AppID:RelativePath:Type)
FLATPAK_APPS=(
    "org.mozilla.firefox:.mozilla/native-messaging-hosts:firefox"
    "io.gitlab.librewolf-community:.librewolf/native-messaging-hosts:firefox"
    "io.gitlab.librewolf-community:.mozilla/native-messaging-hosts:firefox"
    "one.ablaze.floorp:.floorp/native-messaging-hosts:firefox"
    "one.ablaze.floorp:.mozilla/native-messaging-hosts:firefox"
    "net.waterfox.waterfox:.waterfox/native-messaging-hosts:firefox"
    "net.waterfox.waterfox:.mozilla/native-messaging-hosts:firefox"
    "app.zen_browser.zen:.zen/native-messaging-hosts:firefox"
    "app.zen_browser.zen:.mozilla/native-messaging-hosts:firefox"
    "net.mullvad.MullvadBrowser:.mullvad/native-messaging-hosts:firefox"
    "net.mullvad.MullvadBrowser:.mozilla/native-messaging-hosts:firefox"
    "com.brave.Browser:config/BraveSoftware/Brave-Browser/NativeMessagingHosts:chromium"
    "com.brave.Browser:config/BraveSoftware/Brave-Origin/NativeMessagingHosts:chromium"
    "com.brave.Browser.beta:config/BraveSoftware/Brave-Browser-Beta/NativeMessagingHosts:chromium"
    "com.brave.Browser.nightly:config/BraveSoftware/Brave-Browser-Nightly/NativeMessagingHosts:chromium"
    "com.google.Chrome:config/google-chrome/NativeMessagingHosts:chromium"
    "com.google.ChromeDev:config/google-chrome-unstable/NativeMessagingHosts:chromium"
    "org.chromium.Chromium:config/chromium/NativeMessagingHosts:chromium"
    "io.github.ungoogled_software.ungoogled_chromium:config/chromium/NativeMessagingHosts:chromium"
    "io.github.alex313031.Thorium:config/thorium/NativeMessagingHosts:chromium"
    "io.github.alex313031.Thorium:config/chromium/NativeMessagingHosts:chromium"
    "com.microsoft.Edge:config/microsoft-edge/NativeMessagingHosts:chromium"
    "com.microsoft.EdgeDev:config/microsoft-edge-dev/NativeMessagingHosts:chromium"
    "com.vivaldi.Vivaldi:config/vivaldi/NativeMessagingHosts:chromium"
    "com.vivaldi.Vivaldi:config/vivaldi-snapshot/NativeMessagingHosts:chromium"
    "com.opera.Opera:config/opera/NativeMessagingHosts:chromium"
    "com.opera.OperaBeta:config/opera-beta/NativeMessagingHosts:chromium"
    "com.opera.OperaDeveloper:config/opera-developer/NativeMessagingHosts:chromium"
    "com.opera.OperaGX:config/opera-gx/NativeMessagingHosts:chromium"
)

SUITE_VERSION="1.2.0"

show_help() {
    show_banner
    cat << EOF
Usage:
  ./install.sh [options] [path/to/fdm.deb]

Options:
  -h, --help       Show this help message and exit
  -v, --version    Show installer suite version and exit
  -d, --doctor     Run system diagnostic report and verify installation health
  --fix            Instantly repair and synchronize browser manifests & Flatpak permissions
  -f, --force      Force full package re-download even if already up to date
  -a, --autostart  Enable silent autostart on system boot (minimized to tray)
  -y, --yes        Non-interactive mode (automatic yes to prompts)

Arguments:
  [path/to/fdm.deb] Optional local debian package file to install offline

Description:
  Installs Free Download Manager native binaries directly to /opt/freedownloadmanager,
  configures browser Native Messaging Hosts across all Chromium & Firefox browsers
  (supporting Native RPM, Tarball, and Flatpak installations), registers MIME handlers
  for torrent/magnet links, and sets up desktop integration for GNOME & KDE Plasma.
EOF
    exit 0
}

fix_manifests() {
    show_banner
    info "Re-synchronizing Native Messaging manifests & Flatpak permissions across all browsers..."

    # 1. Native Chromium Manifests & Universal Bridge
    for DIR in "${CHROMIUM_NATIVE_DIRS[@]}"; do
        mkdir -p "$DIR" 2>/dev/null || true
        BRIDGE_SCRIPT="$DIR/fdm_bridge.sh"
        cat << 'EOF' > "$BRIDGE_SCRIPT"
#!/bin/sh
if [ -x /usr/bin/flatpak-spawn ]; then
    exec /usr/bin/flatpak-spawn --host /opt/freedownloadmanager/wenativehost "$@"
else
    exec /opt/freedownloadmanager/wenativehost "$@"
fi
EOF
        chmod 755 "$BRIDGE_SCRIPT" 2>/dev/null || true
        cat << EOF > "$DIR/org.freedownloadmanager.fdm5.cnh.json"
{
  "name": "org.freedownloadmanager.fdm5.cnh",
  "description": "Free Download Manager",
  "path": "$BRIDGE_SCRIPT",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://ahmpjcflkgiildlgicmcieglgoilbfdp/",
    "chrome-extension://mdfcjfioplkdchnhcpcobaheocanedjg/"
  ]
}
EOF
        chmod 644 "$DIR/org.freedownloadmanager.fdm5.cnh.json" 2>/dev/null || true
    done

    # 2. Native Firefox & Forks Manifests & Universal Bridge
    for DIR in "${FIREFOX_NATIVE_DIRS[@]}"; do
        mkdir -p "$DIR" 2>/dev/null || true
        BRIDGE_SCRIPT="$DIR/fdm_bridge.sh"
        cat << 'EOF' > "$BRIDGE_SCRIPT"
#!/bin/sh
if [ -x /usr/bin/flatpak-spawn ]; then
    exec /usr/bin/flatpak-spawn --host /opt/freedownloadmanager/wenativehost "$@"
else
    exec /opt/freedownloadmanager/wenativehost "$@"
fi
EOF
        chmod 755 "$BRIDGE_SCRIPT" 2>/dev/null || true
        cat << EOF > "$DIR/org.freedownloadmanager.fdm5.cnh.json"
{
  "name": "org.freedownloadmanager.fdm5.cnh",
  "description": "Free Download Manager",
  "path": "$BRIDGE_SCRIPT",
  "type": "stdio",
  "allowed_extensions": [
    "fdm_ffext@freedownloadmanager.org",
    "fdm_ffext2@freedownloadmanager.org",
    "stream_catcher_fdm@freedownloadmanager.org",
    "stream_catcher_fdm2@freedownloadmanager.org"
  ]
}
EOF
        cat << EOF > "$DIR/com.vms.fdm.json"
{
  "name": "com.vms.fdm",
  "description": "Free Download Manager",
  "path": "$BRIDGE_SCRIPT",
  "type": "stdio",
  "allowed_extensions": [
    "fdm_ffext@freedownloadmanager.org",
    "fdm_ffext2@freedownloadmanager.org",
    "stream_catcher_fdm@freedownloadmanager.org",
    "stream_catcher_fdm2@freedownloadmanager.org"
  ]
}
EOF
        chmod 644 "$DIR/org.freedownloadmanager.fdm5.cnh.json" "$DIR/com.vms.fdm.json" 2>/dev/null || true
    done

    # 3. Flatpak Sandboxes
    if command -v flatpak >/dev/null 2>&1; then
        for ENTRY in "${FLATPAK_APPS[@]}"; do
            APP_ID=$(echo "$ENTRY" | cut -d: -f1)
            REL_PATH=$(echo "$ENTRY" | cut -d: -f2)
            BROWSER_TYPE=$(echo "$ENTRY" | cut -d: -f3)
            TARGET_DIR="$USER_HOME/.var/app/$APP_ID/$REL_PATH"
            mkdir -p "$TARGET_DIR" 2>/dev/null || true
            BRIDGE_SCRIPT="$TARGET_DIR/fdm_bridge.sh"
            cat << 'EOF' > "$BRIDGE_SCRIPT"
#!/bin/sh
if [ -x /usr/bin/flatpak-spawn ]; then
    exec /usr/bin/flatpak-spawn --host /opt/freedownloadmanager/wenativehost "$@"
else
    exec /opt/freedownloadmanager/wenativehost "$@"
fi
EOF
            chmod 755 "$BRIDGE_SCRIPT" 2>/dev/null || true
            if [ "$BROWSER_TYPE" = "firefox" ]; then
                cat << EOF > "$TARGET_DIR/org.freedownloadmanager.fdm5.cnh.json"
{
  "name": "org.freedownloadmanager.fdm5.cnh",
  "description": "Free Download Manager",
  "path": "$BRIDGE_SCRIPT",
  "type": "stdio",
  "allowed_extensions": [
    "fdm_ffext@freedownloadmanager.org",
    "fdm_ffext2@freedownloadmanager.org",
    "stream_catcher_fdm@freedownloadmanager.org",
    "stream_catcher_fdm2@freedownloadmanager.org"
  ]
}
EOF
                cat << EOF > "$TARGET_DIR/com.vms.fdm.json"
{
  "name": "com.vms.fdm",
  "description": "Free Download Manager",
  "path": "$BRIDGE_SCRIPT",
  "type": "stdio",
  "allowed_extensions": [
    "fdm_ffext@freedownloadmanager.org",
    "fdm_ffext2@freedownloadmanager.org",
    "stream_catcher_fdm@freedownloadmanager.org",
    "stream_catcher_fdm2@freedownloadmanager.org"
  ]
}
EOF
                chmod 644 "$TARGET_DIR/org.freedownloadmanager.fdm5.cnh.json" "$TARGET_DIR/com.vms.fdm.json" 2>/dev/null || true
            else
                cat << EOF > "$TARGET_DIR/org.freedownloadmanager.fdm5.cnh.json"
{
  "name": "org.freedownloadmanager.fdm5.cnh",
  "description": "Free Download Manager",
  "path": "$BRIDGE_SCRIPT",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://ahmpjcflkgiildlgicmcieglgoilbfdp/",
    "chrome-extension://mdfcjfioplkdchnhcpcobaheocanedjg/"
  ]
}
EOF
                chmod 644 "$TARGET_DIR/org.freedownloadmanager.fdm5.cnh.json" 2>/dev/null || true
            fi
            if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
                sudo -u "$SUDO_USER" flatpak override --user --talk-name=org.freedesktop.Flatpak "$APP_ID" 2>/dev/null || true
            else
                flatpak override --user --talk-name=org.freedesktop.Flatpak "$APP_ID" 2>/dev/null || true
            fi
        done
    fi

    # Fix ownership if executed with sudo
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.config" "$USER_HOME/.mozilla" "$USER_HOME/.librewolf" "$USER_HOME/.floorp" "$USER_HOME/.waterfox" "$USER_HOME/.zen" "$USER_HOME/.mullvad" "$USER_HOME/.ghostery" 2>/dev/null || true
        if [ -d "$USER_HOME/.var/app" ]; then
            chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.var/app" 2>/dev/null || true
        fi
    fi

    success "Successfully synchronized all browser manifests and Flatpak permissions!"
    echo -e "${DIM}Tip: Restart any open browsers to load the updated extensions.${NC}"
    exit 0
}

run_doctor() {
    show_banner
    echo -e "${BOLD}=== System Diagnostic & Health Audit ===${NC}"
    echo ""

    # 1. Core Binaries
    echo -e "${CYAN}[Core Binaries & CLI Tools]${NC}"
    VERSION_STR=""
    if [ -f /opt/freedownloadmanager/.version ]; then
        VERSION_STR=" (v$(cat /opt/freedownloadmanager/.version | tr -d '[:space:]'))"
    fi

    if [ -f /opt/freedownloadmanager/fdm ] && [ -x /opt/freedownloadmanager/fdm ]; then
        echo -e "  ${GREEN}[✓]${NC} FDM binary: /opt/freedownloadmanager/fdm${VERSION_STR}"
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

    if [ -f /usr/local/bin/fdm-update ] && [ -x /usr/local/bin/fdm-update ]; then
        echo -e "  ${GREEN}[✓]${NC} CLI Updater shortcut: /usr/local/bin/fdm-update"
    fi

    if [ -f /usr/local/bin/fdm-doctor ] && [ -x /usr/local/bin/fdm-doctor ]; then
        echo -e "  ${GREEN}[✓]${NC} CLI Diagnostics shortcut: /usr/local/bin/fdm-doctor"
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

    if [ -f "$USER_HOME/.config/autostart/freedownloadmanager.desktop" ]; then
        echo -e "  ${GREEN}[✓]${NC} Silent Autostart on boot: enabled (~/.config/autostart/freedownloadmanager.desktop)"
    else
        echo -e "  ${DIM}[i] Silent Autostart on boot: disabled (run ./install.sh -a to enable)${NC}"
    fi
    echo ""

    # 3. Browser Manifests
    echo -e "${CYAN}[Browser Native Messaging Manifests (Native & Flatpak)]${NC}"
    for DIR in "${CHROMIUM_NATIVE_DIRS[@]}"; do
        BROWSER_NAME=$(basename "$(dirname "$DIR")")
        if [ -f "$DIR/org.freedownloadmanager.fdm5.cnh.json" ]; then
            echo -e "  ${GREEN}[✓]${NC} $BROWSER_NAME (Native): configured"
        fi
    done

    for DIR in "${FIREFOX_NATIVE_DIRS[@]}"; do
        BROWSER_NAME=$(basename "$(dirname "$DIR")")
        if [ -f "$DIR/org.freedownloadmanager.fdm5.cnh.json" ]; then
            echo -e "  ${GREEN}[✓]${NC} $BROWSER_NAME (Native): configured"
        fi
    done

    for ENTRY in "${FLATPAK_APPS[@]}"; do
        APP_ID=$(echo "$ENTRY" | cut -d: -f1)
        REL_PATH=$(echo "$ENTRY" | cut -d: -f2)
        TARGET_FILE="$USER_HOME/.var/app/$APP_ID/$REL_PATH/org.freedownloadmanager.fdm5.cnh.json"
        if [ -f "$TARGET_FILE" ]; then
            echo -e "  ${GREEN}[✓]${NC} $APP_ID (Flatpak Bridge): configured"
        fi
    done
    echo ""

    # 4. Desktop Environment & System Tray
    echo -e "${CYAN}[Desktop Environment & System Tray]${NC}"
    DETECTED_DESKTOP="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-Unknown}}"
    echo -e "  ${CYAN}[i]${NC} Active Desktop: $DETECTED_DESKTOP"

    if [[ "$DETECTED_DESKTOP" =~ [Kk][Dd][Ee]|[Pp][Ll][Aa][Ss][Mm][Aa] ]]; then
        echo -e "  ${GREEN}[✓]${NC} KDE Plasma: Native StatusNotifierItem & Qt Tray supported natively"
    elif [[ "$DETECTED_DESKTOP" =~ [Gg][Nn][Oo][Mm][Ee] ]]; then
        if rpm -q gnome-shell-extension-appindicator >/dev/null 2>&1; then
            echo -e "  ${GREEN}[✓]${NC} GNOME AppIndicator extension package installed"
        else
            echo -e "  ${YELLOW}[-]${NC} GNOME AppIndicator extension package not installed"
        fi
    else
        echo -e "  ${GREEN}[✓]${NC} System Tray supported"
    fi
    echo ""

    # 5. Background Updates & DNF Integration
    echo -e "${CYAN}[Automatic Updates & DNF Integration]${NC}"
    if [ -f /etc/profile.d/fdm-dnf-hook.sh ]; then
        echo -e "  ${GREEN}[✓]${NC} DNF Hook: active (updates FDM with sudo dnf update)"
    else
        echo -e "  ${YELLOW}[-]${NC} DNF Hook: inactive"
    fi

    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet fdm-update.timer 2>/dev/null; then
        echo -e "  ${GREEN}[✓]${NC} Systemd Auto-Update Timer: active (runs daily)"
    elif [ -f /etc/systemd/system/fdm-update.timer ]; then
        echo -e "  ${YELLOW}[-]${NC} Systemd Auto-Update Timer: installed (inactive)"
    else
        echo -e "  ${YELLOW}[-]${NC} Systemd Auto-Update Timer: not configured"
    fi
    echo ""

    # 6. Network & BitTorrent Firewall Optimization
    echo -e "${CYAN}[Network & BitTorrent Optimization]${NC}"
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
        echo -e "  ${GREEN}[✓]${NC} firewalld: active"
        echo -e "  ${DIM}Tip: To maximize BitTorrent peer connections through firewalld, run:${NC}"
        echo -e "  ${BOLD}sudo firewall-cmd --permanent --add-port=6881-6889/tcp --add-port=6881-6889/udp && sudo firewall-cmd --reload${NC}"
    else
        echo -e "  ${GREEN}[✓]${NC} Firewall: unrestricted or firewalld inactive"
    fi
    echo ""
    echo -e "  ${DIM}Tip: If you installed a new browser, run '${BOLD}fdm-doctor --fix${NC}${DIM}' to sync manifests in 0.1s.${NC}"
    echo ""
    exit 0
}

FORCE_DOWNLOAD=false
ENABLE_AUTOSTART=false
LOCAL_DEB=""

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            show_help
            ;;
        -v|--version)
            echo "Free Download Manager Fedora Installer Suite v${SUITE_VERSION}"
            exit 0
            ;;
        -d|--doctor|--status|--check)
            run_doctor
            ;;
        --fix|-fix)
            fix_manifests
            ;;
        -f|--force)
            FORCE_DOWNLOAD=true
            ;;
        -a|--autostart)
            ENABLE_AUTOSTART=true
            ;;
        -y|--yes)
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

show_banner

# 3. Check for package manager & desktop environment
info "[1/6] Installing system dependencies..."
CORE_DEPS="binutils curl desktop-file-utils xdg-utils bubblewrap libxcb libxkbcommon-x11 libnotify"

# Add GNOME AppIndicator extension only if not strictly KDE Plasma
if [[ "${XDG_CURRENT_DESKTOP:-}" =~ [Kk][Dd][Ee]|[Pp][Ll][Aa][Ss][Mm][Aa] ]]; then
    DESKTOP_DEPS="libappindicator-gtk3"
else
    DESKTOP_DEPS="gnome-shell-extension-appindicator libappindicator-gtk3"
fi

if command -v dnf >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    $SUDO dnf install -y $CORE_DEPS $DESKTOP_DEPS
elif command -v rpm-ostree >/dev/null 2>&1; then
    info "Fedora Atomic (Silverblue/Kinoite/Bazzite) detected."
    warn "Ensure required dependencies are layered with rpm-ostree if not already installed."
else
    warn "Neither dnf nor rpm-ostree found. Proceeding with extraction..."
fi

# Gracefully terminate running FDM instances before extraction
pkill -x fdm 2>/dev/null || true

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
cd "$TMP_DIR" || exit 1

# Check existing installed version to avoid redundant 40MB re-downloads
CURRENT_VERSION=""
if [ -f /opt/freedownloadmanager/.version ]; then
    CURRENT_VERSION=$(cat /opt/freedownloadmanager/.version | tr -d '[:space:]')
fi

SKIP_DOWNLOAD=false
if [ -z "$LOCAL_DEB" ] && [ "$FORCE_DOWNLOAD" != "true" ] && [ -f /opt/freedownloadmanager/fdm ] && [ -n "$CURRENT_VERSION" ]; then
    info "Checking upstream version metadata..."
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

    if [ -n "$REMOTE_VERSION" ] && [ "$CURRENT_VERSION" = "$REMOTE_VERSION" ]; then
        SKIP_DOWNLOAD=true
        success "Free Download Manager (v${CURRENT_VERSION}) is already up to date!"
        info "Skipping 40MB re-download. Refreshing manifests, MIME & desktop integration..."
    fi
fi

if [ "$SKIP_DOWNLOAD" != "true" ]; then
    info "[2/6] Extracting Free Download Manager package..."
    if [ -n "$LOCAL_DEB" ]; then
        info "Using local deb package: $LOCAL_DEB"
        cp "$LOCAL_DEB" fdm.deb
    else
        info "Downloading official Free Download Manager package..."
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

    # Save version metadata
    CONTROL_TAR=$(ar t fdm.deb | grep "control.tar" | head -n 1 || true)
    if [ -n "$CONTROL_TAR" ]; then
        ar p fdm.deb "$CONTROL_TAR" > "$TMP_DIR/$CONTROL_TAR" 2>/dev/null || true
        FDM_VER=$(tar -xaf "$TMP_DIR/$CONTROL_TAR" -O ./control 2>/dev/null | grep -i '^Version:' | awk '{print $2}' || true)
        if [ -n "$FDM_VER" ]; then
            echo "$FDM_VER" | $SUDO tee /opt/freedownloadmanager/.version >/dev/null
        fi
    fi
else
    info "[2/6] Skipping binary extraction (already on v${CURRENT_VERSION})..."
fi

# Create HiDPI & Wayland compatible CLI wrapper in PATH
cat << 'EOF' > "$TMP_DIR/fdm_cli"
#!/usr/bin/env bash
export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
exec /opt/freedownloadmanager/fdm "$@"
EOF
$SUDO cp "$TMP_DIR/fdm_cli" /usr/local/bin/fdm
$SUDO chmod 755 /usr/local/bin/fdm

# Install standalone CLI helper tools (fdm-update, fdm-doctor, fdm-video)
cat << 'EOF' > "$TMP_DIR/fdm_update_cli"
#!/usr/bin/env bash
exec bash -c "$(curl -fsSL https://raw.githubusercontent.com/dain09/fdm-fedora-installer/main/update.sh)" -- "$@"
EOF
$SUDO cp "$TMP_DIR/fdm_update_cli" /usr/local/bin/fdm-update
$SUDO chmod 755 /usr/local/bin/fdm-update

cat << 'EOF' > "$TMP_DIR/fdm_doctor_cli"
#!/usr/bin/env bash
if [ "$1" = "--fix" ] || [ "$1" = "-fix" ]; then
    exec bash -c "$(curl -fsSL https://raw.githubusercontent.com/dain09/fdm-fedora-installer/main/install.sh)" -- --fix
else
    exec bash -c "$(curl -fsSL https://raw.githubusercontent.com/dain09/fdm-fedora-installer/main/install.sh)" -- --doctor "$@"
fi
EOF
$SUDO cp "$TMP_DIR/fdm_doctor_cli" /usr/local/bin/fdm-doctor
$SUDO chmod 755 /usr/local/bin/fdm-doctor

cat << 'EOF' > "$TMP_DIR/fdm_video_cli"
#!/usr/bin/env bash
# Free Download Manager Video Stream Downloader Helper
# Requires: yt-dlp, fdm
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

show_help() {
    echo -e "${CYAN}${BOLD}Free Download Manager - Video Downloader Accelerator${NC}"
    echo "Usage:"
    echo "  fdm-video [options] <URL>"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -a, --audio-only  Extract and download best audio only"
    echo "  -f, --format FMT  Custom stream format selector (passed to yt-dlp)"
    echo ""
    echo "Examples:"
    echo "  fdm-video https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    echo "  fdm-video --audio-only https://soundcloud.com/artist/track"
    exit 0
}

if [ "$#" -eq 0 ]; then
    show_help
fi

AUDIO_ONLY=false
CUSTOM_FORMAT=""
URL=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -a|--audio|--audio-only)
            AUDIO_ONLY=true
            shift
            ;;
        -f|--format)
            CUSTOM_FORMAT="$2"
            shift 2
            ;;
        *)
            URL="$1"
            shift
            ;;
    esac
done

if [ -z "$URL" ]; then
    echo -e "${RED}Error:${NC} No video URL provided."
    exit 1
fi

if ! command -v yt-dlp >/dev/null 2>&1; then
    echo -e "${YELLOW}==>${NC} ${BOLD}yt-dlp is required to extract high-speed video streams.${NC}"
    echo -e "Installing via DNF: ${CYAN}sudo dnf install -y yt-dlp${NC}..."
    sudo dnf install -y yt-dlp || {
        echo -e "${RED}Error:${NC} Failed to install yt-dlp. Please install it with: sudo dnf install yt-dlp"
        exit 1
    }
fi

if [ -n "$CUSTOM_FORMAT" ]; then
    FORMAT_ARG="-f $CUSTOM_FORMAT"
elif [ "$AUDIO_ONLY" = "true" ]; then
    FORMAT_ARG="-f bestaudio/best"
else
    FORMAT_ARG="-f b/bestvideo+bestaudio/best"
fi

echo -e "${CYAN}==>${NC} ${BOLD}Resolving video stream metadata with yt-dlp...${NC}"
TITLE=$(yt-dlp --get-title "$URL" 2>/dev/null || echo "Video Download")
echo -e "${GREEN}==>${NC} ${BOLD}Title:${NC} $TITLE"

# shellcheck disable=SC2086
STREAM_URLS=$(yt-dlp --get-url $FORMAT_ARG "$URL" 2>/dev/null || true)

if [ -z "$STREAM_URLS" ]; then
    echo -e "${RED}Error:${NC} Could not extract direct video streams for: $URL"
    exit 1
fi

echo -e "${CYAN}==>${NC} ${BOLD}Sending stream to Free Download Manager...${NC}"
for S_URL in $STREAM_URLS; do
    /usr/local/bin/fdm "$S_URL" >/dev/null 2>&1 &
done
echo -e "${GREEN}✔${NC} ${BOLD}Download dispatched to Free Download Manager!${NC}"
EOF
$SUDO cp "$TMP_DIR/fdm_video_cli" /usr/local/bin/fdm-video
$SUDO chmod 755 /usr/local/bin/fdm-video

# Install High-Resolution Icons
if [ -f /opt/freedownloadmanager/icon.png ]; then
    $SUDO mkdir -p /usr/share/icons/hicolor/128x128/apps /usr/share/pixmaps 2>/dev/null || true
    $SUDO cp /opt/freedownloadmanager/icon.png /usr/share/icons/hicolor/128x128/apps/freedownloadmanager.png
    $SUDO cp /opt/freedownloadmanager/icon.png /usr/share/pixmaps/freedownloadmanager.png
fi

# Create standardized freedesktop .desktop launcher with Actions
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
Actions=StartHidden;

[Desktop Action StartHidden]
Name=Start Minimized in Tray
Exec=/usr/local/bin/fdm --hidden
EOF
$SUDO cp "$TMP_DIR/freedownloadmanager.desktop" /usr/share/applications/freedownloadmanager.desktop
$SUDO chmod 644 /usr/share/applications/freedownloadmanager.desktop

# Configure Autostart if requested
if [ "$ENABLE_AUTOSTART" = "true" ]; then
    mkdir -p "$USER_HOME/.config/autostart" 2>/dev/null || true
    cat << 'EOF' > "$USER_HOME/.config/autostart/freedownloadmanager.desktop"
[Desktop Entry]
Type=Application
Name=Free Download Manager
Comment=Start Free Download Manager minimized in system tray
Exec=/usr/local/bin/fdm --hidden
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
Terminal=false
Icon=freedownloadmanager
EOF
    chmod 644 "$USER_HOME/.config/autostart/freedownloadmanager.desktop"
    success "Silent autostart on boot enabled (~/.config/autostart/freedownloadmanager.desktop)"
fi

# Bash & Zsh auto-completion
cat << 'EOF' > "$TMP_DIR/fdm_completion"
_fdm_complete() {
    local cur opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    opts="--help --hidden --version"

    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
        return 0
    fi
}
complete -F _fdm_complete fdm

_fdm_update_complete() {
    local cur opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    opts="--help --check --force -h -c -f"

    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
        return 0
    fi
}
complete -F _fdm_update_complete fdm-update

_fdm_doctor_complete() {
    local cur opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    opts="--help -h --fix"

    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
        return 0
    fi
}
complete -F _fdm_doctor_complete fdm-doctor

_fdm_video_complete() {
    local cur opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    opts="--help -h --audio-only -a --format -f"

    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
        return 0
    fi
}
complete -F _fdm_video_complete fdm-video
EOF
$SUDO mkdir -p /usr/share/bash-completion/completions 2>/dev/null || true
$SUDO cp "$TMP_DIR/fdm_completion" /usr/share/bash-completion/completions/fdm
$SUDO cp "$TMP_DIR/fdm_completion" /usr/share/bash-completion/completions/fdm-update
$SUDO cp "$TMP_DIR/fdm_completion" /usr/share/bash-completion/completions/fdm-doctor
$SUDO cp "$TMP_DIR/fdm_completion" /usr/share/bash-completion/completions/fdm-video
$SUDO chmod 644 /usr/share/bash-completion/completions/fdm /usr/share/bash-completion/completions/fdm-update /usr/share/bash-completion/completions/fdm-doctor /usr/share/bash-completion/completions/fdm-video 2>/dev/null || true

# DNF Integration Hook (runs fdm-update alongside sudo dnf update / upgrade)
cat << 'EOF' > "$TMP_DIR/fdm_dnf_hook.sh"
# Free Download Manager automatic update hook for DNF
if [ -n "$BASH_VERSION" ] || [ -n "$ZSH_VERSION" ]; then
    dnf() {
        command dnf "$@"
        local exit_code=$?
        if [ $exit_code -eq 0 ] && [[ "$*" =~ (^|[[:space:]])(update|upgrade)($|[[:space:]]) ]]; then
            if [ -x /usr/local/bin/fdm-update ]; then
                echo ""
                echo -e "\033[0;36m==>\033[0m \033[1mChecking Free Download Manager updates...\033[0m"
                /usr/local/bin/fdm-update
            fi
        fi
        return $exit_code
    }
fi
EOF
$SUDO mkdir -p /etc/profile.d 2>/dev/null || true
$SUDO cp "$TMP_DIR/fdm_dnf_hook.sh" /etc/profile.d/fdm-dnf-hook.sh
$SUDO chmod 644 /etc/profile.d/fdm-dnf-hook.sh

# Systemd Auto-Update Service & Timer (Daily silent background check)
cat << 'EOF' > "$TMP_DIR/fdm-update.service"
[Unit]
Description=Free Download Manager Background Update Check
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fdm-update
EOF

cat << 'EOF' > "$TMP_DIR/fdm-update.timer"
[Unit]
Description=Daily Free Download Manager Update Check

[Timer]
OnBootSec=10min
OnUnitActiveSec=1d
Persistent=true

[Install]
WantedBy=timers.target
EOF

$SUDO cp "$TMP_DIR/fdm-update.service" "$TMP_DIR/fdm-update.timer" /etc/systemd/system/ 2>/dev/null || true
$SUDO chmod 644 /etc/systemd/system/fdm-update.service /etc/systemd/system/fdm-update.timer 2>/dev/null || true
if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
    $SUDO systemctl daemon-reload 2>/dev/null || true
    $SUDO systemctl enable --now fdm-update.timer 2>/dev/null || true
fi

# Refresh desktop database and icon caches across GNOME and KDE
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

info "[3/6] Setting up Universal Native Messaging Hosts..."

# 1. Native Chromium Manifests & Universal Bridge
for DIR in "${CHROMIUM_NATIVE_DIRS[@]}"; do
    mkdir -p "$DIR" 2>/dev/null || true

    BRIDGE_SCRIPT="$DIR/fdm_bridge.sh"
    cat << 'EOF' > "$BRIDGE_SCRIPT"
#!/bin/sh
if [ -x /usr/bin/flatpak-spawn ]; then
    exec /usr/bin/flatpak-spawn --host /opt/freedownloadmanager/wenativehost "$@"
else
    exec /opt/freedownloadmanager/wenativehost "$@"
fi
EOF
    chmod 755 "$BRIDGE_SCRIPT" 2>/dev/null || true

    cat << EOF > "$DIR/org.freedownloadmanager.fdm5.cnh.json"
{
  "name": "org.freedownloadmanager.fdm5.cnh",
  "description": "Free Download Manager",
  "path": "$BRIDGE_SCRIPT",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://ahmpjcflkgiildlgicmcieglgoilbfdp/",
    "chrome-extension://mdfcjfioplkdchnhcpcobaheocanedjg/"
  ]
}
EOF
    chmod 644 "$DIR/org.freedownloadmanager.fdm5.cnh.json" 2>/dev/null || true
done

# System-wide Chromium / Chrome / Edge / Vivaldi directories
CHROMIUM_SYS_JSON='{
  "name": "org.freedownloadmanager.fdm5.cnh",
  "description": "Free Download Manager",
  "path": "/opt/freedownloadmanager/wenativehost",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://ahmpjcflkgiildlgicmcieglgoilbfdp/",
    "chrome-extension://mdfcjfioplkdchnhcpcobaheocanedjg/"
  ]
}'

CHROMIUM_SYS_DIRS=(
    "/etc/opt/chrome/native-messaging-hosts"
    "/etc/chromium/native-messaging-hosts"
    "/etc/opt/brave/native-messaging-hosts"
    "/etc/opt/edge/native-messaging-hosts"
    "/etc/vivaldi/native-messaging-hosts"
    "/etc/opera/native-messaging-hosts"
    "/etc/thorium/native-messaging-hosts"
)
for SYS_DIR in "${CHROMIUM_SYS_DIRS[@]}"; do
    $SUDO mkdir -p "$SYS_DIR" 2>/dev/null || true
    echo "$CHROMIUM_SYS_JSON" | $SUDO tee "$SYS_DIR/org.freedownloadmanager.fdm5.cnh.json" >/dev/null 2>&1 || true
done

# 2. Native Firefox & Forks Manifests & Universal Bridge
for DIR in "${FIREFOX_NATIVE_DIRS[@]}"; do
    mkdir -p "$DIR" 2>/dev/null || true

    BRIDGE_SCRIPT="$DIR/fdm_bridge.sh"
    cat << 'EOF' > "$BRIDGE_SCRIPT"
#!/bin/sh
if [ -x /usr/bin/flatpak-spawn ]; then
    exec /usr/bin/flatpak-spawn --host /opt/freedownloadmanager/wenativehost "$@"
else
    exec /opt/freedownloadmanager/wenativehost "$@"
fi
EOF
    chmod 755 "$BRIDGE_SCRIPT" 2>/dev/null || true

    cat << EOF > "$DIR/org.freedownloadmanager.fdm5.cnh.json"
{
  "name": "org.freedownloadmanager.fdm5.cnh",
  "description": "Free Download Manager",
  "path": "$BRIDGE_SCRIPT",
  "type": "stdio",
  "allowed_extensions": [
    "fdm_ffext@freedownloadmanager.org",
    "fdm_ffext2@freedownloadmanager.org",
    "stream_catcher_fdm@freedownloadmanager.org",
    "stream_catcher_fdm2@freedownloadmanager.org"
  ]
}
EOF

    cat << EOF > "$DIR/com.vms.fdm.json"
{
  "name": "com.vms.fdm",
  "description": "Free Download Manager",
  "path": "$BRIDGE_SCRIPT",
  "type": "stdio",
  "allowed_extensions": [
    "fdm_ffext@freedownloadmanager.org",
    "fdm_ffext2@freedownloadmanager.org",
    "stream_catcher_fdm@freedownloadmanager.org",
    "stream_catcher_fdm2@freedownloadmanager.org"
  ]
}
EOF
    chmod 644 "$DIR/org.freedownloadmanager.fdm5.cnh.json" "$DIR/com.vms.fdm.json" 2>/dev/null || true
done

# System-wide Mozilla directories for native RPM Firefox & forks
FIREFOX_SYS_JSON='{
  "name": "org.freedownloadmanager.fdm5.cnh",
  "description": "Free Download Manager",
  "path": "/opt/freedownloadmanager/wenativehost",
  "type": "stdio",
  "allowed_extensions": [
    "fdm_ffext@freedownloadmanager.org",
    "fdm_ffext2@freedownloadmanager.org",
    "stream_catcher_fdm@freedownloadmanager.org",
    "stream_catcher_fdm2@freedownloadmanager.org"
  ]
}'
COM_VMS_SYS_JSON='{
  "name": "com.vms.fdm",
  "description": "Free Download Manager",
  "path": "/opt/freedownloadmanager/wenativehost",
  "type": "stdio",
  "allowed_extensions": [
    "fdm_ffext@freedownloadmanager.org",
    "fdm_ffext2@freedownloadmanager.org",
    "stream_catcher_fdm@freedownloadmanager.org",
    "stream_catcher_fdm2@freedownloadmanager.org"
  ]
}'
$SUDO mkdir -p /usr/lib64/mozilla/native-messaging-hosts /usr/lib/mozilla/native-messaging-hosts /etc/mozilla/native-messaging-hosts 2>/dev/null || true
echo "$FIREFOX_SYS_JSON" | $SUDO tee /usr/lib64/mozilla/native-messaging-hosts/org.freedownloadmanager.fdm5.cnh.json >/dev/null 2>&1 || true
echo "$COM_VMS_SYS_JSON" | $SUDO tee /usr/lib64/mozilla/native-messaging-hosts/com.vms.fdm.json >/dev/null 2>&1 || true
echo "$FIREFOX_SYS_JSON" | $SUDO tee /usr/lib/mozilla/native-messaging-hosts/org.freedownloadmanager.fdm5.cnh.json >/dev/null 2>&1 || true
echo "$COM_VMS_SYS_JSON" | $SUDO tee /usr/lib/mozilla/native-messaging-hosts/com.vms.fdm.json >/dev/null 2>&1 || true
echo "$FIREFOX_SYS_JSON" | $SUDO tee /etc/mozilla/native-messaging-hosts/org.freedownloadmanager.fdm5.cnh.json >/dev/null 2>&1 || true
echo "$COM_VMS_SYS_JSON" | $SUDO tee /etc/mozilla/native-messaging-hosts/com.vms.fdm.json >/dev/null 2>&1 || true

# 3. Universal Flatpak Sandbox Bridges (Firefox & Chromium Families)
if command -v flatpak >/dev/null 2>&1; then
    for ENTRY in "${FLATPAK_APPS[@]}"; do
        APP_ID=$(echo "$ENTRY" | cut -d: -f1)
        REL_PATH=$(echo "$ENTRY" | cut -d: -f2)
        BROWSER_TYPE=$(echo "$ENTRY" | cut -d: -f3)

        TARGET_DIR="$USER_HOME/.var/app/$APP_ID/$REL_PATH"
        BRIDGE_SCRIPT="$TARGET_DIR/fdm_bridge.sh"
        mkdir -p "$TARGET_DIR" 2>/dev/null || true

        cat << 'EOF' > "$BRIDGE_SCRIPT"
#!/bin/sh
if [ -x /usr/bin/flatpak-spawn ]; then
    exec /usr/bin/flatpak-spawn --host /opt/freedownloadmanager/wenativehost "$@"
else
    exec /opt/freedownloadmanager/wenativehost "$@"
fi
EOF
        chmod 755 "$BRIDGE_SCRIPT" 2>/dev/null || true

        if [ "$BROWSER_TYPE" = "firefox" ]; then
            cat << EOF > "$TARGET_DIR/org.freedownloadmanager.fdm5.cnh.json"
{
  "name": "org.freedownloadmanager.fdm5.cnh",
  "description": "Free Download Manager",
  "path": "$BRIDGE_SCRIPT",
  "type": "stdio",
  "allowed_extensions": [
    "fdm_ffext@freedownloadmanager.org",
    "fdm_ffext2@freedownloadmanager.org",
    "stream_catcher_fdm@freedownloadmanager.org",
    "stream_catcher_fdm2@freedownloadmanager.org"
  ]
}
EOF
            cat << EOF > "$TARGET_DIR/com.vms.fdm.json"
{
  "name": "com.vms.fdm",
  "description": "Free Download Manager",
  "path": "$BRIDGE_SCRIPT",
  "type": "stdio",
  "allowed_extensions": [
    "fdm_ffext@freedownloadmanager.org",
    "fdm_ffext2@freedownloadmanager.org",
    "stream_catcher_fdm@freedownloadmanager.org",
    "stream_catcher_fdm2@freedownloadmanager.org"
  ]
}
EOF
            chmod 644 "$TARGET_DIR/org.freedownloadmanager.fdm5.cnh.json" "$TARGET_DIR/com.vms.fdm.json" 2>/dev/null || true
        else
            cat << EOF > "$TARGET_DIR/org.freedownloadmanager.fdm5.cnh.json"
{
  "name": "org.freedownloadmanager.fdm5.cnh",
  "description": "Free Download Manager",
  "path": "$BRIDGE_SCRIPT",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://ahmpjcflkgiildlgicmcieglgoilbfdp/",
    "chrome-extension://mdfcjfioplkdchnhcpcobaheocanedjg/"
  ]
}
EOF
            chmod 644 "$TARGET_DIR/org.freedownloadmanager.fdm5.cnh.json" 2>/dev/null || true
        fi

        # Grant Flatpak host spawn permission to app proactively
        if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
            sudo -u "$SUDO_USER" flatpak override --user --talk-name=org.freedesktop.Flatpak "$APP_ID" 2>/dev/null || true
        fi
        flatpak override --user --talk-name=org.freedesktop.Flatpak "$APP_ID" 2>/dev/null || true
    done
fi

# Fix permissions for non-root target directories if run via sudo
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.config" "$USER_HOME/.mozilla" "$USER_HOME/.librewolf" "$USER_HOME/.floorp" "$USER_HOME/.waterfox" "$USER_HOME/.zen" "$USER_HOME/.mullvad" "$USER_HOME/.ghostery" 2>/dev/null || true
    if [ -d "$USER_HOME/.var/app" ]; then
        chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.var/app" 2>/dev/null || true
    fi
fi

info "[4/6] Registering MIME associations..."
xdg-mime default freedownloadmanager.desktop application/x-bittorrent 2>/dev/null || true
xdg-mime default freedownloadmanager.desktop x-scheme-handler/magnet 2>/dev/null || true

info "[5/6] Removing conflicting Flatpak version if present..."
if command -v flatpak >/dev/null 2>&1; then
    flatpak uninstall -y org.freedownloadmanager.Manager 2>/dev/null || true
fi

info "[6/6] Finalizing setup..."
echo ""
echo -e "${GREEN}${BOLD}┌──────────────────────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}${BOLD}│  ✔ Free Download Manager installed & configured seamlessly!  │${NC}"
echo -e "${GREEN}${BOLD}├──────────────────────────────────────────────────────────────┤${NC}"
echo -e "  ${BOLD}• App Launcher :${NC} Search 'Free Download Manager' in your menu"
echo -e "  ${BOLD}• CLI Launch   :${NC} ${CYAN}fdm &${NC} or ${CYAN}fdm <url>${NC}"
echo -e "  ${BOLD}• Update Tool  :${NC} ${CYAN}fdm-update${NC} (or ${CYAN}fdm-update --check${NC})"
echo -e "  ${BOLD}• Video Helper :${NC} ${CYAN}fdm-video <url>${NC}"
echo -e "  ${BOLD}• Health Audit :${NC} ${CYAN}fdm-doctor${NC} (or ${CYAN}fdm-doctor --fix${NC})"
if [ "$ENABLE_AUTOSTART" = "true" ]; then
    echo -e "  ${BOLD}• Autostart    :${NC} ${GREEN}Enabled (silent tray on boot)${NC}"
else
    echo -e "  ${BOLD}• Autostart    :${NC} Run ${CYAN}./install.sh -a${NC} to start with system"
fi
echo -e "${GREEN}${BOLD}└──────────────────────────────────────────────────────────────┘${NC}"
echo ""
send_desktop_notification "Free Download Manager" "Installation completed successfully! (v${TARGET_VERSION})" "freedownloadmanager"