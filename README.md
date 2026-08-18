# FDM Native Installer for Fedora Linux

If you've ever tried using **Free Download Manager (FDM)** on Fedora via Flatpak, you probably ran into the same annoying issues:
1. The browser extension refuses to communicate with the app due to sandbox isolation (`Native Messaging Host` errors).
2. The app closes completely instead of staying quietly in the background when minimized.

This repository provides a lightweight script that extracts the official native build directly to `/opt`, wires up the Native Messaging manifests for Chromium-based browsers & Firefox, and configures GNOME tray support.

---

## What the Script Does

* **Native Extraction:** Extracts the official `.deb` binaries to `/opt/freedownloadmanager` without needing an APT-based system.
* **Fixes Browser Integration:** Properly configures Native Messaging manifests across:
  * Brave Browser & Brave Origin
  * Google Chrome & Chromium
  * Mozilla Firefox
* **GNOME AppIndicator:** Installs the required extension packages so FDM can minimize to the top bar properly.
* **Cleans Up Conflicts:** Removes lingering Flatpak background processes that block ports.

---

## One-Line Install

```bash
git clone https://github.com/dain09/fdm-fedora-installer.git
cd fdm-fedora-installer
chmod +x install.sh
./install.sh
```

---

## After Running the Script

1. Install the extension for your browser:
   * **Chrome/Brave:** Install from the Chrome Web Store.
   * **Firefox:** Install from Firefox Add-ons (AMO).
2. Open FDM from your application menu.
3. Log out and log back in (or restart GNOME) to let the top-bar tray icon appear.
4. Try downloading any file — the extension should catch it instantly.

---

## Uninstallation

If you ever want to completely remove FDM and its integration configs:

```bash
sudo rm -rf /opt/freedownloadmanager
sudo rm -f /usr/share/applications/freedownloadmanager.desktop
find ~/.config ~/.mozilla /etc -name "*freedownloadmanager*.json" -delete 2>/dev/null
update-desktop-database
```
