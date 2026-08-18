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

This repository provides an automated installation suite that extracts the official native binaries directly to `/opt/freedownloadmanager`, sets up **Native Messaging Hosts** and **Flatpak Sandbox Bridges** across all major browsers, configures system tray integration, deploys high-resolution application icons, creates a Wayland/HiDPI CLI wrapper, and registers MIME handlers.

---

## ⚡ Quick Start (One-Line Install)

Run the following command in your terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dain09/fdm-fedora-installer/main/install.sh)"
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
  * **Google Chrome**, **Chromium**, & **Beta/Dev/Unstable** (Native & Flatpak)
  * **Brave Browser**, **Brave Origin**, & **Beta/Nightly** (Native & Flatpak)
  * **Microsoft Edge** & **Edge Dev/Beta** (Native & Flatpak)
  * **Vivaldi** & **Vivaldi Snapshot** (Native & Flatpak)
  * **Opera** & **Opera Beta/Developer** (Native & Flatpak)
  * **Mozilla Firefox**, **LibreWolf**, **Floorp**, **Waterfox** & **Zen Browser** (Native & Flatpak)
* **💻 HiDPI & Wayland CLI Wrapper:** Creates `/usr/local/bin/fdm` with automatic screen scaling (`QT_AUTO_SCREEN_SCALE_FACTOR=1`) and adaptive Wayland/X11 rendering.
* **🧩 Full Desktop & System Tray Integration:**
  * **GNOME:** Installs and verifies `gnome-shell-extension-appindicator` and `libappindicator-gtk3`.
  * **KDE Plasma:** Natively integrates with KDE's `StatusNotifierItem` and automatically refreshes `kbuildsycoca` application caches.
* **🧲 Default URL & MIME Handlers:** Registers FDM with `xdg-mime` to handle `application/x-bittorrent` files and `x-scheme-handler/magnet` links.
* **⚡ Smart Bandwidth Optimization:** Both `install.sh` and `update.sh` probe upstream release metadata (~300KB) and skip redundant 40MB downloads if your system is already on the latest version.
* **🩺 Built-in System Doctor (`--doctor`):** Comprehensive diagnostic tool to audit binary executables, browser manifests, MIME handlers, and desktop environment health.

---

## 🚀 Browser Extension Setup

After running the installer, install the official FDM extension in your browser:

* **Chromium Browsers (Chrome, Brave, Edge, Vivaldi, Opera):**  
  Install from the [Chrome Web Store](https://chromewebstore.google.com/detail/free-download-manager-chr/ahmpjcflkgiildlgicmcieglgoilbfdp).
* **Firefox Family (Firefox, LibreWolf, Floorp, Waterfox, Zen):**  
  Install from [Firefox Add-ons (AMO)](https://addons.mozilla.org/firefox/addon/free-download-manager-addon/).

> **Note:** Restart your browser once after installing the extension to load newly configured native messaging hosts.

---

## 💻 CLI Usage

You can launch FDM, pass URLs, or download torrents directly from your terminal:

```bash
# Launch FDM in background
fdm &

# Download a direct file link
fdm https://example.com/file.zip

# Open a BitTorrent magnet link
fdm "magnet:?xt=urn:btih:..."
```

---

## 🩺 System Doctor Diagnosis

Audit your installation health at any time:

```bash
./install.sh --doctor
```

Or via one-liner:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dain09/fdm-fedora-installer/main/install.sh)" -- --doctor
```

Example diagnostic report:
```text
========================================================
   Free Download Manager (FDM) - System Doctor Report   
========================================================

[Core Binaries]
  [✓] FDM binary: /opt/freedownloadmanager/fdm (v6.34.4.6974)
  [✓] Native messaging host: /opt/freedownloadmanager/wenativehost
  [✓] CLI Command wrapper: /usr/local/bin/fdm

[Desktop & MIME Integration]
  [✓] Desktop launcher: /usr/share/applications/freedownloadmanager.desktop
  [✓] Torrent MIME handler: freedownloadmanager.desktop
  [✓] Magnet MIME handler: freedownloadmanager.desktop

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

To update FDM binaries to the latest release:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dain09/fdm-fedora-installer/main/update.sh)"
```

### Options:
* **Check for updates without downloading:**
  ```bash
  ./update.sh --check
  ```
* **Force re-download and reinstallation:**
  ```bash
  ./update.sh --force
  ```

---

## 🗑️ Uninstallation

To completely remove Free Download Manager, its desktop entry, icons, CLI wrapper, and all browser manifests:

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

## 🤝 Contributing

Contributions, bug reports, and feature suggestions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
