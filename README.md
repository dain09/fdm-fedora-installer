# Free Download Manager (FDM) Native Installer for Fedora Linux

[![Fedora](https://img.shields.io/badge/Fedora-Supported-blue?logo=fedora&logoColor=white)](https://getfedora.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Test Installer on Fedora](https://github.com/dain09/fdm-fedora-installer/actions/workflows/test.yml/badge.svg)](https://github.com/dain09/fdm-fedora-installer/actions/workflows/test.yml)

If you've ever tried using **Free Download Manager (FDM)** on Fedora via Flatpak, you probably ran into the same common issues:
1. **Broken Browser Integration:** The browser extension fails to communicate with the app due to sandbox isolation (`Native Messaging Host` errors).
2. **Missing Tray Icon:** The app closes completely instead of staying quietly in the background when minimized.

This repository provides an automated installation script that extracts the official native build directly to `/opt`, sets up **Native Messaging** hosts for all major browsers (Chromium-based & Firefox), configures GNOME tray support, and registers torrent/magnet URL handlers.

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

* **📦 Native Extraction:** Extracts the official `.deb` binaries directly to `/opt/freedownloadmanager` without requiring `dpkg`/`apt`.
* **🌐 Full Browser Integration:** Configures Native Messaging manifests (`org.freedownloadmanager.fdm5.cnh.json`) across:
  * **Brave Browser** & **Brave Origin**
  * **Google Chrome** & **Chromium**
  * **Mozilla Firefox** (`fdm_ffext@freedownloadmanager.org`)
* **🧩 GNOME AppIndicator Support:** Installs `gnome-shell-extension-appindicator` and `libappindicator-gtk3` so FDM can minimize to the top bar properly.
* **🧲 Default Torrent & Magnet Handler:** Registers FDM with `xdg-mime` to open `.torrent` files and `magnet:` links automatically.
* **🧹 Cleans Up Conflicts:** Removes lingering Flatpak background processes and conflicting installations.

---

## 🚀 After Running the Script

1. **Install the Browser Extension:**
   * **Chrome / Brave / Chromium:** Install from the [Chrome Web Store](https://chromewebstore.google.com/detail/free-download-manager-chr/ahmpjcflkgiildlgicmcieglgoilbfdp).
   * **Mozilla Firefox:** Install from [Firefox Add-ons (AMO)](https://addons.mozilla.org/firefox/addon/free-download-manager-addon/).
2. **Launch FDM** from your application menu.
3. **Log out and log back in** (or restart GNOME Shell) to enable the top-bar tray icon.
4. Download any file or click a magnet link — FDM will catch it instantly!

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

To completely remove Free Download Manager, its desktop entry, and all browser manifests:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dain09/fdm-fedora-installer/main/uninstall.sh)"
```

Or run locally if cloned:
```bash
./uninstall.sh
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
