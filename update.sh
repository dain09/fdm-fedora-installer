#!/usr/bin/env bash
# Free Download Manager In-Place Updater for Fedora Linux
# Author: Abdallah Ibrahim (@dain09)
# Repository: https://github.com/dain09/fdm-fedora-installer
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
  _____ ____  __  __   _   _           _       _            
 |  ___|  _ \|  \/  | | | | |_ __   __| | __ _| |_ ___ _ __ 
 | |_  | | | | |\/| | | | | | '_ \ / _` |/ _` | __/ _ \ '__|
 |  _| | |_| | |  | | | |_| | |_) | (_| | (_| | ||  __/ |   
 |_|   |____/|_|  |_|  \___/| .__/ \__,_|\__,_|\__\___|_|   
                            |_|                             
EOF
    echo -e "${NC}${CYAN} Free Download Manager In-Place Updater${NC}"
    echo -e "${DIM} Maintained by Abdallah Ibrahim (@dain09) | github.com/dain09/fdm-fedora-installer${NC}"
    echo -e "${DIM}------------------------------------------------------------${NC}"
}

SUITE_VERSION="1.2.0"

show_help() {
    show_banner
    cat << EOF
Usage:
  ./update.sh [options]

Options:
  -h, --help       Show this help message and exit
  -v, --version    Show updater version and exit
  -f, --force      Force update / re-download even if already up to date
  -c, --check      Check for updates without downloading or installing
  -y, --yes        Non-interactive mode

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
        -v|--version)
            echo "Free Download Manager In-Place Updater v${SUITE_VERSION}"
            exit 0
            ;;
        -f|--force)
            FORCE_UPDATE=true
            ;;
        -c|--check)
            CHECK_ONLY=true
            ;;
        -y|--yes)
            ;;
    esac
done

show_banner

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

FDM_MIRRORS=(
    "https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb"
    "https://files.freedownloadmanager.org/6/latest/freedownloadmanager.deb"
    "https://dn3.freedownloadmanager.org/6/latest/freedownloadmanager.deb"
)

download_with_fallback() {
    local target_file="$1"
    local partial_probe="${2:-false}"
    local download_success=false

    for mirror in "${FDM_MIRRORS[@]}"; do
        if [ "$partial_probe" = "true" ]; then
            if curl -fsSL --retry 3 --retry-delay 2 --retry-connrefused -r 0-300000 -o "$target_file" "$mirror" 2>/dev/null; then
                download_success=true
                break
            fi
        else
            if curl -fL --retry 5 --retry-delay 2 --retry-connrefused -C - -o "$target_file" "$mirror"; then
                download_success=true
                break
            else
                warn "Download from $mirror failed or timed out. Trying fallback mirror..."
            fi
        fi
    done

    if [ "$download_success" != "true" ]; then
        return 1
    fi
}

info "Checking for upstream updates..."

# Probe the first ~300KB to read the control archive version without downloading 40MB
REMOTE_VERSION=""
if download_with_fallback "$TMP_DIR/fdm_probe.deb" true; then
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

# Download the full official deb package with multi-mirror fallback
if ! download_with_fallback fdm.deb false; then
    error "Failed to download Free Download Manager from all mirrors. Please verify your connection."
    exit 1
fi

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

# Install standalone CLI helper tools (fdm-update and fdm-doctor)
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

cat << 'EOF' > "$TMP_DIR/fdm_dl_cli"
#!/usr/bin/env bash
# Free Download Manager Accelerated CLI Media Downloader
# Powered by yt-dlp with multi-connection chunk acceleration
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

format_bytes() {
    local b="$1"
    if [ -z "$b" ] || [ "$b" = "NA" ] || [ "$b" = "None" ]; then
        echo "Dynamic / Unknown"
        return
    fi
    awk -v b="$b" 'BEGIN {
        if (b >= 1073741824) printf "%.2f GB\n", b / 1073741824;
        else if (b >= 1048576) printf "%.2f MB\n", b / 1048576;
        else if (b >= 1024) printf "%.2f KB\n", b / 1024;
        else printf "%d B\n", b;
    }'
}

show_help() {
    echo -e "${CYAN}${BOLD}Free Download Manager - Accelerated Media Downloader (fdm-dl)${NC}"
    echo "Usage:"
    echo "  fdm-dl [options] <URL>"
    echo ""
    echo "Options:"
    echo "  -h, --help            Show this help message"
    echo "  -y, --yes             Skip confirmation prompt and start download immediately"
    echo "  -a, --audio-only      Extract and download audio only (best quality MP3/M4A)"
    echo "  -q, --quality RES     Target maximum video resolution (e.g. 1080p, 720p, 4k)"
    echo "  -o, --output DIR      Custom destination folder (default: ~/Downloads)"
    echo "  -c, --connections N   Number of parallel download streams (default: 8)"
    echo "  --coffee              Secret developer fuel ☕"
    echo "  --rickroll            Experience the legendary internet tradition 🕺"
    echo ""
    echo "Examples:"
    echo "  fdm-dl https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    echo "  fdm-dl -y https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    echo "  fdm-dl -a https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    echo "  fdm-dl -q 1080p https://twitter.com/user/status/123456789"
    exit 0
}

# Detect actual user home for Downloads folder
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    TARGET_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    TARGET_HOME="$HOME"
fi

DEST_DIR="$TARGET_HOME/Downloads"
AUDIO_ONLY=false
AUTO_CONFIRM=false
TARGET_RES=""
CONCURRENT=8
URL=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        --coffee)
            echo -e "${YELLOW}"
            cat << 'COFFEE_EOF'
      (  )   (   )  )
       ) (   )  (  (
       ( )  (    ) )
       ____________
      <____________> ___
      |            |/ _ \
      |  FDM Brew  | | | |
      |   Coffee   |\___/
      |____________|
COFFEE_EOF
            echo -e "${NC}${BOLD}Brewing caffeine while your 8 download threads fly! ☕🚀${NC}"
            exit 0
            ;;
        --rickroll)
            URL="https://www.youtube.com/watch?v=dQw4w9WgXcQ"
            AUTO_CONFIRM=true
            shift
            ;;
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        -a|--audio|--audio-only)
            AUDIO_ONLY=true
            shift
            ;;
        -q*)
            if [ "$1" = "-q" ] || [ "$1" = "--quality" ]; then
                TARGET_RES="$2"
                shift 2
            else
                TARGET_RES="${1#-q}"
                shift 1
            fi
            ;;
        --quality=*)
            TARGET_RES="${1#--quality=}"
            shift 1
            ;;
        -o|--output)
            DEST_DIR="$2"
            shift 2
            ;;
        -c|--connections)
            CONCURRENT="$2"
            shift 2
            ;;
        *)
            URL="$1"
            shift
            ;;
    esac
done

if [ -z "$URL" ]; then
    if [ -t 0 ]; then
        echo -ne "${CYAN}🔗 Paste media URL (YouTube, Twitter, TikTok...): ${NC}"
        read -r URL
        URL=$(echo "$URL" | tr -d '\r\n[:space:]')
    fi
fi

if [ -z "$URL" ]; then
    echo -e "${RED}Error:${NC} No URL provided."
    echo -e "Run '${BOLD}fdm-dl --help${NC}' for usage instructions."
    exit 1
fi

# Ensure yt-dlp and nodejs are installed
MISSING_PKGS=""
if ! command -v yt-dlp >/dev/null 2>&1; then
    MISSING_PKGS="$MISSING_PKGS yt-dlp"
fi
if ! command -v node >/dev/null 2>&1; then
    MISSING_PKGS="$MISSING_PKGS nodejs"
fi

if [ -n "$MISSING_PKGS" ]; then
    echo -e "${YELLOW}==>${NC} ${BOLD}Installing required dependencies ($MISSING_PKGS)...${NC}"
    # shellcheck disable=SC2086
    sudo dnf install -y $MISSING_PKGS || {
        echo -e "${RED}Error:${NC} Failed to install dependencies. Please run: sudo dnf install $MISSING_PKGS"
        exit 1
    }
fi

mkdir -p "$DEST_DIR" 2>/dev/null || true

# Format selection & enforce single song/video download (--no-playlist)
if [ "$AUDIO_ONLY" = "true" ]; then
    YTDL_OPTS=(--no-playlist -x --audio-format mp3 --audio-quality 0)
    MODE_STR="Audio Only (High-Quality MP3)"
elif [ -n "$TARGET_RES" ]; then
    CLEAN_RES=$(echo "$TARGET_RES" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    case "$CLEAN_RES" in
        *4k*)
            RES_NUM=2160
            ;;
        *2k*|*1440*)
            RES_NUM=1440
            ;;
        *)
            RES_NUM=$(echo "$CLEAN_RES" | tr -cd '0-9')
            ;;
    esac

    if [ -n "$RES_NUM" ]; then
        YTDL_OPTS=(--no-playlist -f "bestvideo[height<=${RES_NUM}]+bestaudio/best[height<=${RES_NUM}]/best")
        MODE_STR="Video (${RES_NUM}p)"
    else
        YTDL_OPTS=(--no-playlist -f "bestvideo+bestaudio/best")
        MODE_STR="Best Available Quality (Video + Audio)"
    fi
else
    YTDL_OPTS=(--no-playlist -f "bestvideo+bestaudio/best")
    MODE_STR="Best Available Quality (Video + Audio)"
fi

echo -e "${CYAN}==>${NC} ${BOLD}Analyzing media stream metadata...${NC}"

META_RAW=$(yt-dlp --js-runtimes node \
                  --remote-components ejs:github \
                  --extractor-args "youtube:player_client=web,android" \
                  --no-warnings \
                  --print "%(title)s:::%(uploader,channel)s:::%(duration_string)s:::%(filesize,filesize_approx)s" \
                  "${YTDL_OPTS[@]}" \
                  "$URL" 2>/dev/null | tail -n 1 || true)

TITLE=$(echo "$META_RAW" | awk -F':::' '{print $1}')
UPLOADER=$(echo "$META_RAW" | awk -F':::' '{print $2}')
DURATION=$(echo "$META_RAW" | awk -F':::' '{print $3}')
RAW_SIZE=$(echo "$META_RAW" | awk -F':::' '{print $4}')

[ -z "$TITLE" ] && TITLE="Media Download"
[ -z "$UPLOADER" ] && UPLOADER="Unknown"
[ -z "$DURATION" ] && DURATION="N/A"
EST_SIZE=$(format_bytes "$RAW_SIZE")

echo ""
echo -e "${CYAN}${BOLD}┌──────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}${BOLD}│  🎬 Free Download Manager - Media Downloader (@dain09)       │${NC}"
echo -e "${CYAN}${BOLD}├──────────────────────────────────────────────────────────────┤${NC}"
printf "  ${BOLD}• Title       :${NC} %-48.48s\n" "$TITLE"
printf "  ${BOLD}• Source/Host :${NC} %-48.48s\n" "$UPLOADER"
printf "  ${BOLD}• Duration    :${NC} %-48.48s\n" "$DURATION"
printf "  ${BOLD}• Format/Mode :${NC} %-48.48s\n" "$MODE_STR"
printf "  ${BOLD}• Est. Size   :${NC} %-48.48s\n" "$EST_SIZE"
printf "  ${BOLD}• Destination :${NC} %-48.48s\n" "$DEST_DIR"
printf "  ${BOLD}• Acceleration:${NC} %-48.48s\n" "$CONCURRENT Parallel Connections"
echo -e "${CYAN}${BOLD}└──────────────────────────────────────────────────────────────┘${NC}"
echo ""

if [ "$AUTO_CONFIRM" != "true" ] && [ -t 0 ]; then
    read -r -p "Proceed with accelerated download? [Y/n] " CONFIRM
    CONFIRM=${CONFIRM:-Y}
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Download cancelled. Rick Astley is disappointed in you... 😔🕺${NC}"
        exit 0
    fi
fi

echo -e "${GREEN}==>${NC} ${BOLD}Starting multi-threaded accelerated download...${NC}"
echo ""

START_TIME=$(date +%s)

# Execute download with custom formatted progress bar
yt-dlp -N "$CONCURRENT" \
       --js-runtimes node \
       --remote-components ejs:github \
       --extractor-args "youtube:player_client=web,android" \
       --no-warnings \
       --progress \
       -P "$DEST_DIR" \
       -o "%(title)s.%(ext)s" \
       "${YTDL_OPTS[@]}" \
       "$URL"

EXIT_CODE=$?
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
[ $ELAPSED -eq 0 ] && ELAPSED=1

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}${BOLD}✔ Download Completed in ${ELAPSED}s!${NC}"
    echo -e "  Saved to: ${CYAN}${BOLD}$DEST_DIR${NC}"
    
    # Desktop Notification with Title and Size
    if command -v notify-send >/dev/null 2>&1; then
        NOTIF_BODY="$TITLE ($EST_SIZE)"
        if [ "$URL" = "https://www.youtube.com/watch?v=dQw4w9WgXcQ" ]; then
            NOTIF_TITLE="You just got Rickrolled in 4K by @dain09! 🕺🎶"
        else
            NOTIF_TITLE="Media Download Complete (⚡ ${ELAPSED}s)"
        fi

        if [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
            notify-send -i freedownloadmanager -a "Free Download Manager" "$NOTIF_TITLE" "$NOTIF_BODY" 2>/dev/null || true
        elif [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
            local_uid=$(id -u "$SUDO_USER" 2>/dev/null || true)
            if [ -S "/run/user/$local_uid/bus" ]; then
                sudo -u "$SUDO_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$local_uid/bus" \
                    notify-send -i freedownloadmanager -a "Free Download Manager" "$NOTIF_TITLE" "$NOTIF_BODY" 2>/dev/null || true
            fi
        fi
    fi
else
    echo ""
    echo -e "${RED}Error:${NC} Download interrupted or failed with code $EXIT_CODE."
    exit $EXIT_CODE
fi
EOF
$SUDO cp "$TMP_DIR/fdm_dl_cli" /usr/local/bin/fdm-dl
$SUDO cp "$TMP_DIR/fdm_dl_cli" /usr/local/bin/fdm-video
$SUDO chmod 755 /usr/local/bin/fdm-dl /usr/local/bin/fdm-video

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
Actions=StartHidden;

[Desktop Action StartHidden]
Name=Start Minimized in Tray
Exec=/usr/local/bin/fdm --hidden
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
send_desktop_notification "Free Download Manager" "Successfully updated to v${REMOTE_VERSION:-latest}" "freedownloadmanager"

