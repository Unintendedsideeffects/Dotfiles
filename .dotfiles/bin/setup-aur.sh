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

# Determine if we need sudo
use_sudo=""
if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    use_sudo="sudo"
fi

# Ensure we have git and base-devel
echo "📦 Installing prerequisites..."
$use_sudo pacman -S --needed --noconfirm git base-devel

# Create temporary directory
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

# Clone yay repository
echo "📥 Cloning yay repository..."
git clone https://aur.archlinux.org/yay.git

# Build and install yay
echo "🔨 Building yay..."
cd yay
makepkg -si --noconfirm

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