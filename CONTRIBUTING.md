# Contributing to FDM Fedora Installer

Thank you for your interest in improving the **FDM Native Installer for Fedora Linux**! Contributions from the community are warmly welcomed.

---

## 🛠️ How to Contribute

### 1. Reporting Issues
* Search existing issues to avoid duplicates.
* When reporting bugs, include:
  * Your Fedora version and desktop environment (GNOME, KDE, etc.).
  * The browser and extension version.
  * Exact terminal output / errors.

### 2. Suggesting Enhancements
* Open a [Feature Request](https://github.com/dain09/fdm-fedora-installer/issues/new/choose) describing the functionality and use case.

### 3. Submitting Pull Requests
1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/my-new-feature`.
3. Make your changes and ensure scripts pass syntax check:
   ```bash
   bash -n install.sh update.sh uninstall.sh
   ```
4. Test locally or using Docker:
   ```bash
   docker run --rm -v "$PWD:/workspace" -w /workspace fedora:latest /bin/bash -c "./install.sh && ./update.sh && ./uninstall.sh"
   ```
5. Commit with descriptive messages (preferably [Conventional Commits](https://www.conventionalcommits.org/)).
6. Push to your branch and open a Pull Request.

---

## 📜 Code Guidelines
* Maintain compatibility with Fedora Workstation and Fedora Atomic (Silverblue/Kinoite).
* Use `$SUDO` variable detection rather than hardcoding `sudo`.
* Keep temporary file handling clean using `trap ... EXIT INT TERM`.
