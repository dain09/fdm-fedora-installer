# Free Download Manager (FDM) Native Installer for Fedora Linux

[![Fedora](https://img.shields.io/badge/Fedora-Supported-blue?logo=fedora&logoColor=white)](https://getfedora.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![CI Test Suite](https://github.com/dain09/fdm-fedora-installer/actions/workflows/test.yml/badge.svg)](https://github.com/dain09/fdm-fedora-installer/actions/workflows/test.yml)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Passing-brightgreen?logo=gnu-bash&logoColor=white)](https://www.shellcheck.net/)

An automated, production-ready installer and updater for native **Free Download Manager (FDM)** on **Fedora Linux** (Workstation, KDE Spin, and Atomic / Silverblue / Kinoite / Bazzite).

---

## 🎯 Why This Project?

While Free Download Manager is available on Flathub, sandboxing limitations cause common issues on Linux:
1. **Broken Browser Integration:** Extensions cannot communicate with the sandboxed app, causing "Native Host Not Found" or "Settings aren't available" errors.
2. **Missing System Tray:** The application closes completely instead of minimizing to the background tray on GNOME and KDE Plasma.
3. **Missing Torrent / Magnet Associations:** Magnet links and `.torrent` files fail to open in FDM by default.

This repository provides an automated installation suite that extracts the official native binaries directly to `/opt/freedownloadmanager`, sets up **Native Messaging Hosts** and **Flatpak Sandbox Bridges** across all major browsers, configures system tray integration, deploys high-resolution application icons, creates a Wayland/HiDPI CLI wrapper with helper tools (`fdm`, `fdm-update`, `fdm-doctor`), and registers MIME handlers.

---

## ⚡ Quick Start (One-Line Install)

Run the following command in your terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dain09/fdm-fedora-installer/main/install.sh)"
```

### Optional Flags:
* **Enable silent autostart on system boot (minimized to tray):**
  ```bash
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/dain09/fdm-fedora-installer/main/install.sh)" -- --autostart
  ```
* **Run system diagnostics only:**
  ```bash
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/dain09/fdm-fedora-installer/main/install.sh)" -- --doctor
  ```

<details>
<summary><b>Alternative: Manual Installation via Git</b></summary>

```bash
git clone https://github.com/dain09/fdm-fedora-installer.git
cd fdm-fedora-installer
chmod +x install.sh update.sh uninstall.sh
./install.sh
```

</details>

---

## ✨ Features

* **📦 Native Extraction & Integrity Verification:** Extracts official `.deb` binaries directly into `/opt/freedownloadmanager` without requiring `dpkg` or `apt`.
* **🌐 Universal Browser Integration (Native & Flatpak):** Configures Native Messaging manifests (`org.freedownloadmanager.fdm5.cnh` & `com.vms.fdm`) and automated sandbox bridges across:
  * **Google Chrome**, **Chromium**, **Thorium**, & **Beta/Dev/Unstable** (Native & Flatpak)
  * **Brave Browser**, **Brave Origin**, & **Beta/Nightly** (Native & Flatpak)
  * **Microsoft Edge** & **Edge Dev/Beta** (Native & Flatpak)
  * **Vivaldi** & **Vivaldi Snapshot** (Native & Flatpak)
  * **Opera** & **Opera Beta/Developer** (Native & Flatpak)
  * **Mozilla Firefox**, **LibreWolf**, **Floorp**, **Waterfox** & **Zen Browser** (Native & Flatpak)
* **💻 HiDPI & Wayland CLI Wrapper:** Creates `/usr/local/bin/fdm` with automatic screen scaling (`QT_AUTO_SCREEN_SCALE_FACTOR=1`) and adaptive Wayland/X11 rendering.
* **🛠️ Standalone CLI Helpers:** Installs `fdm-update` for one-command updates and `fdm-doctor` for instant system diagnostics.
* **🧩 Full Desktop & System Tray Integration:**
  * **GNOME:** Installs and verifies `gnome-shell-extension-appindicator` and `libappindicator-gtk3`.
  * **KDE Plasma:** Natively integrates with KDE's `StatusNotifierItem` and automatically refreshes `kbuildsycoca` application caches.
  * **Desktop Actions:** Right-click context menu in dock/taskbar with "Start Minimized in Tray" option.
* **🧲 Default URL & MIME Handlers:** Registers FDM with `xdg-mime` to handle `application/x-bittorrent` files and `x-scheme-handler/magnet` links.
* **⚡ Smart Bandwidth Optimization:** Both `install.sh` and `update.sh` probe upstream release metadata (~300KB) and skip redundant 40MB downloads if your system is already on the latest version.
* **🩺 Built-in System Doctor (`--doctor`):** Comprehensive diagnostic tool to audit binary executables, browser manifests, MIME handlers, and desktop environment health.

---

## 🚀 Browser Extension Setup

After running the installer, install the official FDM extension in your browser:

* **Chromium Browsers (Chrome, Brave, Edge, Vivaldi, Opera, Thorium):**  
  Install from the [Chrome Web Store](https://chromewebstore.google.com/detail/free-download-manager-chr/ahmpjcflkgiildlgicmcieglgoilbfdp).
* **Firefox Family (Firefox, LibreWolf, Floorp, Waterfox, Zen):**  
  Install from [Firefox Add-ons (AMO)](https://addons.mozilla.org/firefox/addon/free-download-manager-addon/).

> **Note:** Restart your browser once after installing the extension to load newly configured native messaging hosts.

---

## 💻 CLI Commands

| Command | Description |
| :--- | :--- |
| `fdm` | Launch Free Download Manager GUI |
| `fdm &` | Launch FDM in background |
| `fdm --hidden` | Launch FDM silently minimized to the system tray |
| `fdm <url>` | Pass a direct download link or magnet URI to FDM |
| `fdm-dl <url>` | Multi-threaded CLI media downloader (YouTube, X/Twitter, TikTok, etc.) |
| `fdm-update` | Check for upstream releases and update FDM in-place |
| `fdm-update --check` | Check if a newer version is available without downloading |
| `fdm-doctor` | Run comprehensive system integration health checks |
| `fdm-doctor --fix` | Instantly synchronize manifests & permissions for newly installed browsers |

---

## 🎬 Accelerated CLI Media Downloader (`fdm-dl`)

Download videos and audio directly from the terminal with 8 parallel accelerated connection chunks to `~/Downloads`:

```bash
# Download highest quality video (4K/1080p + audio)
fdm-dl https://www.youtube.com/watch?v=dQw4w9WgXcQ

# Extract audio only (High quality MP3)
fdm-dl -a https://www.youtube.com/watch?v=dQw4w9WgXcQ

# Specify max resolution (e.g. 1080p, 720p)
fdm-dl -q 1080p https://twitter.com/user/status/123456789
```

---

## 🩺 System Doctor & Auto-Repair

Audit your installation health at any time by running:

```bash
fdm-doctor
```

Or instantly repair and sync manifests for any newly installed browsers:
```bash
fdm-doctor --fix
```

Example diagnostic report:
```text
========================================================
   Free Download Manager (FDM) - System Doctor Report   
========================================================

[Core Binaries & CLI Tools]
  [✓] FDM binary: /opt/freedownloadmanager/fdm (v6.34.4.6974)
  [✓] Native messaging host: /opt/freedownloadmanager/wenativehost
  [✓] CLI Command wrapper: /usr/local/bin/fdm
  [✓] CLI Updater command: /usr/local/bin/fdm-update
  [✓] CLI Doctor command: /usr/local/bin/fdm-doctor

[Desktop & MIME Integration]
  [✓] Desktop launcher: /usr/share/applications/freedownloadmanager.desktop
  [✓] Torrent MIME handler: freedownloadmanager.desktop
  [✓] Magnet MIME handler: freedownloadmanager.desktop
  [✓] Silent Autostart on boot: enabled (~/.config/autostart/freedownloadmanager.desktop)

[Browser Native Messaging Manifests (Native & Flatpak)]
  [✓] Brave-Origin (Native): configured
  [✓] Brave-Browser (Native): configured
  [✓] google-chrome (Native): configured
  [✓] org.mozilla.firefox (Flatpak Bridge): configured
  [✓] com.microsoft.Edge (Flatpak Bridge): configured

[Desktop Environment & System Tray]
  [i] Active Desktop: GNOME
  [✓] GNOME AppIndicator extension package installed
```

---

## 🔄 Updating FDM

FDM updates are handled effortlessly through three convenient methods:

### 1. Automatic Updates with `sudo dnf update` (Built-in Hook)
When you run `sudo dnf update` or `dnf upgrade`, the installer's profile hook (`/etc/profile.d/fdm-dnf-hook.sh`) automatically checks upstream FDM releases right after DNF finishes updating your system packages.

### 2. Automatic Daily Background Timer (`systemd`)
The installer configures a lightweight `systemd` user timer (`fdm-update.timer`) that silently checks for upstream updates once a day (using a ~300KB probe) without consuming bandwidth.

### 3. Manual On-Demand Update (CLI)
You can manually check or update at any time:

```bash
# Update to latest release in-place
fdm-update

# Check for updates without downloading
fdm-update --check
```

---

## 🗑️ Uninstallation

To completely remove Free Download Manager, its desktop entry, icons, CLI wrappers, autostart entries, and all browser manifests:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dain09/fdm-fedora-installer/main/uninstall.sh)"
```

Or run locally if cloned:
```bash
./uninstall.sh
```

---

## 🔧 Troubleshooting

<details>
<summary><b>1. System Tray Icon does not appear in GNOME</b></summary>

Make sure the AppIndicator extension is enabled in GNOME Shell:
```bash
gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com
```
Then restart your GNOME session (or log out and log back in).
</details>

<details>
<summary><b>2. Fedora Silverblue / Atomic Desktops (Kinoite, Bazzite)</b></summary>

On immutable Fedora distributions, system packages must be layered using `rpm-ostree`:
```bash
rpm-ostree install binutils curl desktop-file-utils xdg-utils bubblewrap libxcb libxkbcommon-x11 gnome-shell-extension-appindicator libappindicator-gtk3
```
After rebooting, run the installer one-liner normally.
</details>

<details>
<summary><b>3. Wayland Window Scaling or Decoration Issues</b></summary>

If you experience window decoration issues on certain Wayland compositors, you can force XWayland rendering via environment variable:
```bash
QT_QPA_PLATFORM=xcb fdm
```
</details>

---

## ⚖️ Legal Disclaimer

This repository and its installation scripts are an **independent, community-driven open-source project** and are **NOT affiliated, associated, authorized, endorsed by, or in any way officially connected with FreeDownloadManager.org, Softdeluxe, or Free Download Manager Ltd.**

* **Trademarks:** "Free Download Manager", "FDM", and associated logos are trademarks of FreeDownloadManager.org / Softdeluxe. All other product and browser names are trademarks of their respective holders. Their use is strictly for descriptive and compatibility identification purposes (*Nominative Fair Use*).
* **No Software Redistribution:** This project does not host, redistribute, or modify any proprietary FDM binary packages. All files are downloaded directly from the official upstream vendor servers during installation.
* See [DISCLAIMER.md](DISCLAIMER.md) for full legal terms.

---

## 🤝 Contributing

Contributions, bug reports, and feature suggestions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

