#!/usr/bin/env bash
set -euo pipefail

# AUR Helper Setup for Arch Linux
# Installs yay (Yet Another Yaourt) for AUR package management

# Check if running on Arch
if ! command -v pacman >/dev/null 2>&1; then
    echo "❌ This script is only for Arch Linux systems"
    exit 1
fi

# Check if yay is already installed
if command -v yay >/dev/null 2>&1; then
    echo "✅ yay is already installed"
    yay --version
    exit 0
fi

echo "🔧 Installing yay AUR helper..."

# Helper function to run commands with sudo when needed
run_cmd() {
    if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        "$@"
    fi
}

# Ensure we have git and base-devel
echo "📦 Installing prerequisites..."
run_cmd pacman -S --needed --noconfirm git base-devel

# Create temporary directory
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

# Clone yay repository with retry logic
echo "📥 Cloning yay repository..."
for attempt in 1 2 3; do
    if git clone https://aur.archlinux.org/yay.git; then
        break
    else
        echo "⚠️ Clone attempt $attempt failed, retrying..."
        sleep 2
        rm -rf yay 2>/dev/null || true
        if [[ $attempt -eq 3 ]]; then
            echo "❌ Failed to clone yay repository after 3 attempts"
            echo "This might be a network connectivity issue."
            echo "You can try running this script again later."
            exit 1
        fi
    fi
done

# Build and install yay
echo "🔨 Building yay..."
cd yay
if ! makepkg -si --noconfirm; then
    echo "❌ Failed to build yay"
    echo "This might be due to missing dependencies or build errors."
    exit 1
fi

# Cleanup
cd /
rm -rf "$TMP_DIR"

# Verify installation
if command -v yay >/dev/null 2>&1; then
    echo "✅ yay installed successfully!"
    yay --version
    
    # Configure yay with sensible defaults
    echo "⚙️  Configuring yay..."
    yay --save --answerclean All --answerdiff None --answerupgrade None --cleanafter
    
    echo "💡 yay is now ready to use!"
    echo "   - Install AUR packages: yay -S package-name"
    echo "   - Update all packages: yay -Syu"
    echo "   - Search packages: yay -Ss search-term"
else
    echo "❌ yay installation failed"
    exit 1
fi