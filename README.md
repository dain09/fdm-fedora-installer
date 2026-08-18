# Free Download Manager (FDM) Native Installer for Fedora Linux

[![Fedora](https://img.shields.io/badge/Fedora-Supported-blue?logo=fedora&logoColor=white)](https://getfedora.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![CI Test Suite](https://github.com/dain09/fdm-fedora-installer/actions/workflows/test.yml/badge.svg)](https://github.com/dain09/fdm-fedora-installer/actions/workflows/test.yml)

If you've ever tried using **Free Download Manager (FDM)** on Fedora via Flatpak, you probably ran into the same common issues:
1. **Broken Browser Integration:** The browser extension fails to communicate with the app due to sandbox isolation (`Native Messaging Host` errors).
2. **Missing Tray Icon:** The app closes completely instead of staying quietly in the background when minimized.

This repository provides an automated installation script that extracts the official native build directly to `/opt`, sets up **Native Messaging** hosts across all major browsers, configures GNOME tray support, creates a terminal command wrapper (optimized for HiDPI/Wayland), and registers torrent/magnet URL handlers.

---

## ⚡ Quick One-Line Install (Recommended)

Run the following command directly in your terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dain09/fdm-fedora-installer/main/install.sh)"
```

<details>
<summary><b>Alternative: Manual Installation via Git</b></summary>

```bash
git clone https://github.com/dain09/fdm-fedora-installer.git
cd fdm-fedora-installer
chmod +x install.sh
./install.sh
```

</details>

---

## 🛠️ What the Script Does

* **📦 Native Extraction & Integrity Check:** Verifies and extracts the official `.deb` binaries directly to `/opt/freedownloadmanager` without requiring `dpkg`/`apt`.
* **🌐 Universal Browser Integration:** Configures Native Messaging manifests (`org.freedownloadmanager.fdm5.cnh.json`) across:
  * **Google Chrome** & **Chromium**
  * **Brave Browser** & **Brave Origin**
  * **Microsoft Edge** & **Edge Dev**
  * **Vivaldi** & **Opera**
  * **Mozilla Firefox**, **LibreWolf**, **Floorp** & **Waterfox** (`fdm_ffext@freedownloadmanager.org`)
* **💻 Command-Line Interface (CLI):** Creates a wrapper `/usr/local/bin/fdm` with automatic HiDPI scaling so you can launch FDM directly from terminal (e.g., `fdm <url>`).
* **🧩 GNOME AppIndicator Support:** Installs `gnome-shell-extension-appindicator` and `libappindicator-gtk3` so FDM can minimize to the top bar properly.
* **🧲 Default Torrent & Magnet Handler:** Registers FDM with `xdg-mime` to open `.torrent` files and `magnet:` links automatically.
* **🧹 Cleans Up Conflicts:** Removes lingering Flatpak background processes and conflicting installations.

---

## 🚀 After Running the Script

1. **Install the Browser Extension:**
   * **Chrome / Brave / Edge / Vivaldi / Opera:** Install from the [Chrome Web Store](https://chromewebstore.google.com/detail/free-download-manager-chr/ahmpjcflkgiildlgicmcieglgoilbfdp).
   * **Mozilla Firefox / LibreWolf / Floorp:** Install from [Firefox Add-ons (AMO)](https://addons.mozilla.org/firefox/addon/free-download-manager-addon/).
2. **Launch FDM** from your application menu or run `fdm` in terminal.
3. **Log out and log back in** (or restart GNOME Shell) to enable the top-bar tray icon.
4. Download any file or click a magnet link — FDM will catch it instantly!

---

## 💻 CLI Usage

You can launch FDM or send download links directly from your terminal:

```bash
# Launch FDM in background
fdm &

# Download a direct file link
fdm https://example.com/file.zip

# Open a magnet link
fdm "magnet:?xt=urn:btih:..."
```

---

## 🩺 System Doctor Diagnosis

You can run the built-in diagnostic tool at any time to verify your installation health:

```bash
./install.sh --doctor
```

Or via one-liner:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dain09/fdm-fedora-installer/main/install.sh)" -- --doctor
```

---

## 🔄 Updating FDM

To update the FDM binaries to the latest release without re-configuring your browsers or settings:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dain09/fdm-fedora-installer/main/update.sh)"
```

Or run locally if cloned:
```bash
./update.sh
```

---

## 🗑️ Uninstallation

To completely remove Free Download Manager, its desktop entry, CLI wrapper, and all browser manifests:

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
<summary><b>1. System Tray Icon doesn't appear after login</b></summary>

Make sure the AppIndicator extension is enabled in GNOME:
```bash
gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com
```
Then restart your session or press `Alt + F2`, type `r` (on X11), and press Enter.
</details>

<details>
<summary><b>2. Fedora Silverblue / Atomic Desktops (Kinoite, Bazzite)</b></summary>

On immutable Fedora desktops, system packages must be layered using `rpm-ostree`:
```bash
rpm-ostree install binutils curl desktop-file-utils xdg-utils gnome-shell-extension-appindicator libappindicator-gtk3
```
After layering and rebooting, run the installer one-liner as usual.
</details>

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Check out our [Contributing Guidelines](CONTRIBUTING.md).

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
