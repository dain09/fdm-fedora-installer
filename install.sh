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
    "$USER_HOME/.config/microsoft-edge/NativeMessagingHosts"
    "$USER_HOME/.config/microsoft-edge-beta/NativeMessagingHosts"
    "$USER_HOME/.config/microsoft-edge-dev/NativeMessagingHosts"
    "$USER_HOME/.config/vivaldi/NativeMessagingHosts"
    "$USER_HOME/.config/vivaldi-snapshot/NativeMessagingHosts"
    "$USER_HOME/.config/opera/NativeMessagingHosts"
    "$USER_HOME/.config/opera-beta/NativeMessagingHosts"
    "$USER_HOME/.config/opera-developer/NativeMessagingHosts"
)

# Native Firefox-based Manifest Paths (RPM / Tarball & Forks)
FIREFOX_NATIVE_DIRS=(
    "$USER_HOME/.mozilla/native-messaging-hosts"
    "$USER_HOME/.librewolf/native-messaging-hosts"
    "$USER_HOME/.floorp/native-messaging-hosts"
    "$USER_HOME/.waterfox/native-messaging-hosts"
    "$USER_HOME/.zen/native-messaging-hosts"
)

# Flatpak Browser App Definitions (AppID:RelativePath:Type)
FLATPAK_APPS=(
    "org.mozilla.firefox:.mozilla/native-messaging-hosts:firefox"
    "io.gitlab.librewolf-community:.librewolf/native-messaging-hosts:firefox"
    "one.ablaze.floorp:.floorp/native-messaging-hosts:firefox"
    "one.ablaze.floorp:.mozilla/native-messaging-hosts:firefox"
    "net.waterfox.waterfox:.waterfox/native-messaging-hosts:firefox"
    "app.zen_browser.zen:.zen/native-messaging-hosts:firefox"
    "app.zen_browser.zen:.mozilla/native-messaging-hosts:firefox"
    "com.brave.Browser:config/BraveSoftware/Brave-Browser/NativeMessagingHosts:chromium"
    "com.google.Chrome:config/google-chrome/NativeMessagingHosts:chromium"
    "com.google.ChromeDev:config/google-chrome-unstable/NativeMessagingHosts:chromium"
    "org.chromium.Chromium:config/chromium/NativeMessagingHosts:chromium"
    "com.microsoft.Edge:config/microsoft-edge/NativeMessagingHosts:chromium"
    "com.microsoft.EdgeDev:config/microsoft-edge-dev/NativeMessagingHosts:chromium"
    "com.vivaldi.Vivaldi:config/vivaldi/NativeMessagingHosts:chromium"
    "com.opera.Opera:config/opera/NativeMessagingHosts:chromium"
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
  configures browser Native Messaging Hosts across all Chromium & Firefox browsers
  (supporting Native RPM, Tarball, and Flatpak installations), registers MIME handlers
  for torrent/magnet links, and sets up desktop integration for GNOME & KDE Plasma.
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

# 3. Check for package manager & desktop environment
info "[1/6] Installing system dependencies..."
CORE_DEPS="binutils curl desktop-file-utils xdg-utils"

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

# Save version metadata
CONTROL_TAR=$(ar t fdm.deb | grep "control.tar" | head -n 1 || true)
if [ -n "$CONTROL_TAR" ]; then
    ar p fdm.deb "$CONTROL_TAR" > "$TMP_DIR/$CONTROL_TAR" 2>/dev/null || true
    FDM_VER=$(tar -xaf "$TMP_DIR/$CONTROL_TAR" -O ./control 2>/dev/null | grep -i '^Version:' | awk '{print $2}' || true)
    if [ -n "$FDM_VER" ]; then
        echo "$FDM_VER" | $SUDO tee /opt/freedownloadmanager/.version >/dev/null
    fi
fi

# Create HiDPI & Wayland compatible CLI wrapper in PATH
cat << 'EOF' > "$TMP_DIR/fdm_cli"
#!/usr/bin/env bash
export QT_AUTO_SCREEN_SCALE_FACTOR=1
exec /opt/freedownloadmanager/fdm "$@"
EOF
$SUDO cp "$TMP_DIR/fdm_cli" /usr/local/bin/fdm
$SUDO chmod 755 /usr/local/bin/fdm

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

# 1. Native Chromium Manifest
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

for DIR in "${CHROMIUM_NATIVE_DIRS[@]}"; do
    mkdir -p "$DIR" 2>/dev/null || true
    echo "$CHROMIUM_JSON" > "$DIR/org.freedownloadmanager.fdm5.cnh.json" 2>/dev/null || true
    chmod 644 "$DIR/org.freedownloadmanager.fdm5.cnh.json" 2>/dev/null || true
done

# System-wide Chromium / Chrome / Edge / Vivaldi directories
CHROMIUM_SYS_DIRS=(
    "/etc/opt/chrome/native-messaging-hosts"
    "/etc/chromium/native-messaging-hosts"
    "/etc/opt/edge/native-messaging-hosts"
    "/etc/vivaldi/native-messaging-hosts"
    "/etc/opera/native-messaging-hosts"
)
for SYS_DIR in "${CHROMIUM_SYS_DIRS[@]}"; do
    $SUDO mkdir -p "$SYS_DIR" 2>/dev/null || true
    echo "$CHROMIUM_JSON" | $SUDO tee "$SYS_DIR/org.freedownloadmanager.fdm5.cnh.json" >/dev/null 2>&1 || true
done

# 2. Native Firefox & Forks Manifest
FIREFOX_JSON='{
  "name": "org.freedownloadmanager.fdm5.cnh",
  "description": "Free Download Manager",
  "path": "/opt/freedownloadmanager/wenativehost",
  "type": "stdio",
  "allowed_extensions": [
    "fdm_ffext@freedownloadmanager.org",
    "stream_catcher_fdm@freedownloadmanager.org"
  ]
}'

for DIR in "${FIREFOX_NATIVE_DIRS[@]}"; do
    mkdir -p "$DIR" 2>/dev/null || true
    echo "$FIREFOX_JSON" > "$DIR/org.freedownloadmanager.fdm5.cnh.json" 2>/dev/null || true
    chmod 644 "$DIR/org.freedownloadmanager.fdm5.cnh.json" 2>/dev/null || true
done

# System-wide Mozilla directories for native RPM Firefox
$SUDO mkdir -p /usr/lib64/mozilla/native-messaging-hosts /usr/lib/mozilla/native-messaging-hosts 2>/dev/null || true
echo "$FIREFOX_JSON" | $SUDO tee /usr/lib64/mozilla/native-messaging-hosts/org.freedownloadmanager.fdm5.cnh.json >/dev/null 2>&1 || true
echo "$FIREFOX_JSON" | $SUDO tee /usr/lib/mozilla/native-messaging-hosts/org.freedownloadmanager.fdm5.cnh.json >/dev/null 2>&1 || true

# 3. Universal Flatpak Sandbox Bridges (Firefox & Chromium Families)
if command -v flatpak >/dev/null 2>&1; then
    for ENTRY in "${FLATPAK_APPS[@]}"; do
        APP_ID=$(echo "$ENTRY" | cut -d: -f1)
        REL_PATH=$(echo "$ENTRY" | cut -d: -f2)
        BROWSER_TYPE=$(echo "$ENTRY" | cut -d: -f3)

        TARGET_DIR="$USER_HOME/.var/app/$APP_ID/$REL_PATH"
        BRIDGE_SCRIPT="$TARGET_DIR/fdm_flatpak_bridge.sh"
        mkdir -p "$TARGET_DIR" 2>/dev/null || true

        cat << 'EOF' > "$BRIDGE_SCRIPT"
#!/bin/sh
exec /usr/bin/flatpak-spawn --host /opt/freedownloadmanager/wenativehost "$@"
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
    "stream_catcher_fdm@freedownloadmanager.org"
  ]
}
EOF
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
        fi
        chmod 644 "$TARGET_DIR/org.freedownloadmanager.fdm5.cnh.json" 2>/dev/null || true

        # Grant Flatpak host spawn permission to app
        flatpak override --user --talk-name=org.freedesktop.Flatpak "$APP_ID" 2>/dev/null || true
    done
fi

# Fix permissions for non-root target directories if run via sudo
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.config" "$USER_HOME/.mozilla" "$USER_HOME/.librewolf" "$USER_HOME/.floorp" "$USER_HOME/.waterfox" "$USER_HOME/.zen" 2>/dev/null || true
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
echo "--------------------------------------------------------"
success "Free Download Manager has been installed successfully!"
echo -e "You can launch it from your applications menu or type '${BOLD}fdm${NC}' in your terminal."
echo -e "Please restart your browser to activate the extension."