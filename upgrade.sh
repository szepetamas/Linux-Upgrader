#!/bin/bash

# ==============================================================================
# GRAND UNIFIED LINUX MAINTENANCE SCRIPT (v7.0)
# Target: Any Linux Distribution, Any Version (Past/Present/Future).
# Context: Headless, GUI, SSH, Cron, User, Root.
# ==============================================================================

# 1. ROBUST ENVIRONMENT SETUP
# ---------------------------
# Use 'set -e' to stop on errors, but use '|| true' in commands where failure is acceptable.
set -e
# We do not use 'set -u' here because ancient environments might have empty variables 
# that would crash the script.

# Aggressively unset GUI variables. 
# This fixes "X11 connection rejected" on servers with HDMI dummy plugs.
unset DISPLAY
unset XAUTHORITY
unset SESSION_MANAGER

# Force non-interactive mode for Debian/Ubuntu (prevents blue screens).
export DEBIAN_FRONTEND=noninteractive

# Define a silent helper function for command checking (POSIX compliant)
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "=== Starting Universal System Maintenance ==="

# 2. CONTEXT & PRIVILEGE ELEVATION
# --------------------------------
# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    IS_ROOT=true
    SUDO_CMD=""
    echo "Context: Running as Root (Cron/Sudo)."
else
    IS_ROOT=false
    SUDO_CMD="sudo"
    echo "Context: Running as Normal User."
    
    # Refresh sudo credential cache if sudo exists
    if command_exists sudo; then
        sudo -v
        # Keep sudo alive in background
        ( while true; do sudo -v; sleep 60; done; ) &
        SUDO_PID=$!
        trap 'kill $SUDO_PID' EXIT
    else
        echo "Error: You are not root and 'sudo' is missing. Cannot proceed."
        exit 1
    fi
fi

# 3. SELF-HEALING (Debian/Ubuntu Specific)
# ----------------------------------------
# Fixes interrupted updates from previous runs.
if command_exists dpkg; then
    echo "--- [Self-Healing] Checking package database ---"
    $SUDO_CMD dpkg --configure -a || echo "  Warning: dpkg repair encountered issues, continuing..."
fi

# 4. PACKAGE MANAGER DETECTION & UPDATE
# -------------------------------------
# We check binaries, not OS names. This is more robust across versions.

# A. Debian / Ubuntu / Mint / Proxmox / Kali (apt-get is universal, apt is newer)
if command_exists apt-get; then
    echo "--- [APT] Detected. Updating System ---"
    
    # 1. Update lists
    $SUDO_CMD apt-get update -q
    
    # 2. Upgrade
    # Use 'dist-upgrade' (or full-upgrade). It handles kernel changes better than 'upgrade'.
    # We pass Dpkg options to auto-accept old config files (headless safety).
    echo "--- [APT] performing Dist/Full Upgrade ---"
    $SUDO_CMD apt-get dist-upgrade -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    
    # 3. Cleanup
    echo "--- [APT] Cleaning garbage ---"
    $SUDO_CMD apt-get autoremove -yq --purge
    $SUDO_CMD apt-get autoclean -yq
    $SUDO_CMD apt-get clean
    
    # 4. RC (Residual Config) Cleanup
    # Complex pipe handled carefully for empty results
    if [ -n "$(dpkg -l 2>/dev/null | grep "^rc")" ]; then
        echo "--- Removing Residual Config Files ---"
        dpkg -l | grep "^rc" | cut -d " " -f 3 | xargs -r $SUDO_CMD dpkg --purge
    fi

# B. Arch Linux / Manjaro (pacman)
elif command_exists pacman; then
    echo "--- [PACMAN] Detected. Updating System ---"
    $SUDO_CMD pacman -Syu --noconfirm
    
    echo "--- [PACMAN] Cleaning Orphans ---"
    # Arch returns error if no orphans found, so we check first or swallow error
    if $SUDO_CMD pacman -Qtdq >/dev/null 2>&1; then
        $SUDO_CMD pacman -Rns $($SUDO_CMD pacman -Qtdq) --noconfirm
    fi
    $SUDO_CMD pacman -Sc --noconfirm

# C. Modern RedHat / Fedora (dnf)
elif command_exists dnf; then
    echo "--- [DNF] Detected. Updating System ---"
    $SUDO_CMD dnf upgrade --refresh -y
    $SUDO_CMD dnf autoremove -y
    $SUDO_CMD dnf clean all

# D. Ancient RedHat / CentOS (yum)
elif command_exists yum; then
    echo "--- [YUM] Detected. Updating System ---"
    $SUDO_CMD yum update -y
    $SUDO_CMD yum autoremove -y
    $SUDO_CMD yum clean all

# E. Alpine Linux (apk)
elif command_exists apk; then
    echo "--- [APK] Detected. Updating System ---"
    $SUDO_CMD apk update
    $SUDO_CMD apk upgrade

# F. OpenSUSE (zypper)
elif command_exists zypper; then
    echo "--- [ZYPPER] Detected. Updating System ---"
    $SUDO_CMD zypper refresh
    $SUDO_CMD zypper update -y
    $SUDO_CMD zypper clean -a

else
    echo "--- No known package manager found. Skipping core OS update. ---"
fi

# 5. UNIVERSAL COMPONENT UPDATES
# ------------------------------
# These checks allow the script to work on systems from 2004 (which skip this)
# to systems from 2026 (which run this).

# Snaps
if command_exists snap; then
    echo "--- Refreshing Snaps ---"
    $SUDO_CMD snap refresh 2>/dev/null || echo "  Snap refresh skipped/failed."
fi

# Flatpaks
if command_exists flatpak; then
    echo "--- Updating Flatpaks ---"
    $SUDO_CMD flatpak update -y 2>/dev/null || true
fi

# Firmware (Linux Vendor Firmware Service)
# We redirect BOTH stdout and stderr to null to silence "No updates" noise
if command_exists fwupdmgr; then
    echo "--- Checking Firmware Updates ---"
    $SUDO_CMD fwupdmgr refresh --force >/dev/null 2>&1 || true
    if $SUDO_CMD fwupdmgr get-updates >/dev/null 2>&1; then
        echo "  > Firmware updates found! Installing..."
        $SUDO_CMD fwupdmgr update -y || echo "  Firmware update failed."
    else
        echo "  > No firmware updates available."
    fi
fi

# Raspberry Pi Bootloader
if command_exists rpi-eeprom-update; then
    echo "--- Checking Raspberry Pi EEPROM ---"
    $SUDO_CMD rpi-eeprom-update -a
fi

# 6. BOOTLOADER MAINTENANCE (GRUB 2 ONLY)
# ---------------------------------------
# We explicitly do NOT touch Legacy Grub (Grub 1) or Lilo.
if [ -d /boot/grub ]; then
    echo "--- Checking Bootloader Config (Grub 2) ---"
    # Silence all output including standard error to hide os-prober warnings
    if command_exists update-grub; then
        $SUDO_CMD update-grub >/dev/null 2>&1
    elif command_exists grub-mkconfig; then
        $SUDO_CMD grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
    fi
    echo "  > Grub configuration regenerated."
fi

# 7. CONTAINER GARBAGE COLLECTION
# -------------------------------
if command_exists docker; then
    echo "--- Cleaning Docker Garbage ---"
    $SUDO_CMD docker system prune -f >/dev/null 2>&1 || true
fi

if command_exists podman; then
    echo "--- Cleaning Podman Garbage ---"
    $SUDO_CMD podman system prune -f >/dev/null 2>&1 || true
fi

# 8. LOG MAINTENANCE
# ------------------
# Check for systemd-journald (Modern Linux).
# If missing (Ancient Linux), we assume standard logrotate is handling things.
if command_exists journalctl; then
    echo "--- Vacuuming System Logs (Keep 2 weeks) ---"
    $SUDO_CMD journalctl --vacuum-time=2weeks >/dev/null 2>&1 || true
fi

# 9. USER CACHE CLEANUP
# ---------------------
# Only if NOT running as root (to protect permissions)
if [ "$IS_ROOT" = false ]; then
    # Thumbnail cache (Standard Freedesktop location)
    if [ -d "$HOME/.cache/thumbnails" ]; then
        echo "--- Cleaning User Thumbnail Cache ---"
        rm -rf "$HOME/.cache/thumbnails/"* 2>/dev/null || true
    fi
    
    # Safe cleanup of other common user caches could be added here
    # but thumbnails are the biggest offender.
fi

echo "=== System Update & Cleanup Complete ==="
