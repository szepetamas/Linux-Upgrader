**The Grand Unified Linux Maintenance Script.**

A single, robust Bash script designed to keep *any* Linux system updated, clean, and healthy. From ancient servers to modern workstations, from Raspberry Pis to Arch Linux laptops.

**Key Design Philosophy:** "Fire and Forget."

## 🚀 Features

*   **Universal Support:** Works on Ubuntu, Debian, Arch, Manjaro, Fedora, CentOS, Alpine, OpenSUSE, and more.
*   **Context Aware:** Detects if you are running as a **User** (updates system + cleans user thumbails) or **Root/Cron** (updates system only).
*   **Headless Server Optimized:** Aggressively handles "X11 connection rejected" errors caused by HDMI dummy plugs or missing monitors.
*   **Self-Healing:** Automatically attempts to fix broken `dpkg` installations (Debian/Ubuntu) and interrupted updates.
*   **Full Stack Maintenance:**
    *   **OS:** Full distribution upgrades (kernel aware).
    *   **Firmware:** Checks `fwupdmgr` (LVFS) and Raspberry Pi EEPROM.
    *   **Apps:** Updates Snaps and Flatpaks.
    *   **Containers:** Vacuums Docker and Podman garbage (dangling images/stopped containers).
    *   **Bootloader:** Regenerates GRUB2 config to fix "ghost" kernel entries.
    *   **Logs:** Vacuums systemd journals older than 2 weeks.

## 📦 Installation & Usage

### 1. Download
You can clone the repo or just grab the raw script.

```bash
git clone https://github.com/szepetamas/Linux-Upgrader.git
cd Linux-Upgrader
chmod +x upgrade.sh
```

### 2. Standalone Run (Manual)
Run it as your normal user. The script will ask for your `sudo` password **once** and keep the session alive until the job is done.

```bash
./upgrade.sh
```

*Note: Do not run as `sudo ./upgrade.sh` unless you are on a root-only server. Running as a normal user allows the script to safely clean your user-specific cache files.*

### 3. Automated (Cron Job)
The script is designed to run silently and non-interactively when executed by root.

**Example: Run every Sunday at 4:00 AM**
Open your root crontab:
```bash
sudo crontab -e
```
Add the following line:
```cron
0 4 * * 0 /path/to/Linux-Upgrader/upgrade.sh >> /var/log/upgrade.log 2>&1
```

## 🖥️ Supported Distributions
The script detects package managers binaries, not just OS names. If your system has the tool, the script supports it.

| Family | Package Manager | Status |
| :--- | :--- | :--- |
| **Debian / Ubuntu / Mint / Proxmox / Kali** | `apt-get` | ✅ Full Support |
| **Arch Linux / Manjaro / EndeavourOS** | `pacman` | ✅ Full Support |
| **RedHat / Fedora / Alma / Rocky** | `dnf` | ✅ Full Support |
| **Legacy CentOS / RHEL** | `yum` | ✅ Full Support |
| **Alpine Linux** | `apk` | ✅ Full Support |
| **OpenSUSE** | `zypper` | ✅ Full Support |

## 🛠️ Advanced Logic

### The "Headless" Fix
If you run servers with **HDMI Dummy Plugs** (to enable GPU acceleration without a monitor), standard update scripts often crash with `X11 connection rejected`.
This script explicitly unsets `DISPLAY` and `XAUTHORITY` variables and exports `DEBIAN_FRONTEND=noninteractive` to ensure tools like `fwupdmgr` and `apt` never try to spawn a GUI window.

### Safety First
*   **POSIX Compliant Checks:** Uses `command -v` instead of `which` for maximum compatibility.
*   **Legacy GRUB:** It detects `/boot/grub`. It will **not** touch legacy GRUB (version 1) configurations to prevent breaking older legacy systems.
*   **Error Handling:** Uses `set -e` to stop critical failures, but allows optional components (like Docker cleanup) to fail gracefully without stopping the system update.

## 🤝 Contributing
Forks and Pull Requests are welcome! The goal is to keep this script compatible with as many edge-cases and distributions as possible while keeping it in a single file.

## 📄 License
MIT License. Free to use, modify, and distribute.
