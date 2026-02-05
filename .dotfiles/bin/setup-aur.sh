#!/usr/bin/env bash
set -euo pipefail

# AUR Helper Setup for Arch Linux
# Installs yay (Yet Another Yaourt) for AUR package management

# Check if running on Arch
if ! command -v pacman >/dev/null 2>&1; then
    echo "ERROR: This script is only for Arch Linux systems"
    exit 1
fi

# Check if running as root user (not just with sudo)
actual_user="${SUDO_USER:-$USER}"
if [[ "$actual_user" == "root" ]] || [[ $EUID -eq 0 && -z "${SUDO_USER:-}" ]]; then
    echo "ERROR: Cannot install yay as root user"
    echo ""
    echo "AUR helpers should not be run as root for security reasons."
    echo "makepkg (used to build AUR packages) refuses to run as root."
    echo ""
    echo "Please:"
    echo "  1. Create a regular user account"
    echo "  2. Log in as that user"
    echo "  3. Run this script again"
    exit 1
fi

# Check if yay is already installed
if command -v yay >/dev/null 2>&1; then
    echo "OK: yay is already installed"
    yay --version
    exit 0
fi

echo "Installing yay AUR helper..."

# Helper function to run commands with sudo when needed
run_cmd() {
    if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        "$@"
    fi
}

# Ensure we have git and base-devel
echo "Installing prerequisites (including ccache)..."
run_cmd pacman -S --needed --noconfirm git base-devel ccache

# Create temporary directory
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

# Clone yay repository with retry logic
echo "Cloning yay repository..."
for attempt in 1 2 3; do
    if git clone https://aur.archlinux.org/yay.git; then
        break
    else
        echo "WARNING: Clone attempt $attempt failed, retrying..."
        sleep 2
        rm -rf yay 2>/dev/null || true
        if [[ $attempt -eq 3 ]]; then
            echo "ERROR: Failed to clone yay repository after 3 attempts"
            echo "This might be a network connectivity issue."
            echo "You can try running this script again later."
            exit 1
        fi
    fi
done

# Build and install yay
echo "Building yay..."
cd yay
if ! makepkg -si --noconfirm; then
    echo "ERROR: Failed to build yay"
    echo "This might be due to missing dependencies or build errors."
    exit 1
fi

# Cleanup
cd /
rm -rf "$TMP_DIR"

# Verify installation
if command -v yay >/dev/null 2>&1; then
    echo "OK: yay installed successfully!"
    yay --version
    
    # Configure yay with sensible defaults
    echo "Configuring yay..."
    yay --save --answerclean All --answerdiff None --answerupgrade None --cleanafter
    
    echo "yay is now ready to use!"
    echo "   - Install AUR packages: yay -S package-name"
    echo "   - Update all packages: yay -Syu"
    echo "   - Search packages: yay -Ss search-term"

    # Set up cache cleanup
    echo ""
    echo "Setting up package cache cleanup..."

    # Install pacman-contrib for paccache
    run_cmd pacman -S --needed --noconfirm pacman-contrib

    # Enable paccache timer (keeps only last 3 versions of each package)
    # This runs weekly and cleans /var/cache/pacman/pkg/
    run_cmd systemctl enable --now paccache.timer
    echo "OK: paccache.timer enabled (weekly cleanup, keeps 3 versions)"

    # Clean yay's AUR build cache (keeps last 3 builds per package)
    # This is a one-time cleanup; cleanAfter handles ongoing cleanup
    if [[ -d "$HOME/.cache/yay" ]]; then
        echo "Cleaning old AUR build cache..."
        # Remove build directories older than 30 days
        find "$HOME/.cache/yay" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \; 2>/dev/null || true
        echo "OK: Old AUR build cache cleaned"
    fi

    echo ""
    echo "Cache cleanup configured:"
    echo "   - paccache.timer: weekly, keeps 3 package versions"
    echo "   - yay cleanAfter: auto-cleans after each build"
else
    echo "ERROR: yay installation failed"
    exit 1
fi
