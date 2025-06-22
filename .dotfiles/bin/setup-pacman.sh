#!/bin/bash
# Setup script for applying pacman/yay configurations
# Standalone script - also integrated into bootstrap.sh for automatic setup
# Use this for manual application or re-applying configs

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print functions
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running on Arch Linux
if ! command -v pacman &> /dev/null; then
    print_error "This script is for Arch Linux only (pacman not found)"
    exit 1
fi

# Check if running from dotfiles directory
if [[ ! -f ".config/pacman/pacman.conf" ]]; then
    print_error "Run this script from your dotfiles root directory"
    print_error "Expected: .config/pacman/pacman.conf to exist"
    exit 1
fi

print_info "Setting up optimized pacman/yay configurations..."

# 1. Backup existing configurations
print_info "Backing up existing configurations..."
if [[ -f "/etc/pacman.conf" ]]; then
    sudo cp /etc/pacman.conf /etc/pacman.conf.backup
    print_info "Backed up /etc/pacman.conf"
fi

if [[ -f "/etc/makepkg.conf" ]]; then
    sudo cp /etc/makepkg.conf /etc/makepkg.conf.backup
    print_info "Backed up /etc/makepkg.conf"
fi

# 2. Apply optimized configurations
print_info "Applying optimized pacman configuration..."
sudo cp .config/pacman/pacman.conf /etc/pacman.conf

print_info "Applying optimized makepkg configuration..."
sudo cp .config/pacman/makepkg.conf /etc/makepkg.conf

# 3. Set up yay configuration
print_info "Setting up yay configuration..."
mkdir -p ~/.config/yay
cp .config/yay/config.json ~/.config/yay/config.json

# 4. Install ccache if not present
if ! command -v ccache &> /dev/null; then
    print_info "Installing ccache for faster builds..."
    sudo pacman -S --noconfirm ccache
else
    print_info "ccache already installed"
fi

# 5. Create makepkg cache directories
print_info "Creating makepkg cache directories..."
mkdir -p ~/.cache/makepkg/{packages,sources,srcpackages,logs}

# 6. Update package databases
print_info "Updating package databases..."
sudo pacman -Sy

print_info "Package manager setup complete!"
print_info ""
print_info "Optimizations applied:"
print_info "  • Pacman: 8 parallel downloads, color output, progress bars"
print_info "  • Makepkg: Multi-core builds, ccache, LTO optimization"
print_info "  • Yay: Safety features and performance settings"
print_info "  • Cache: User-specific build directories created"
print_info ""
print_info "You can now use pacman and yay with optimized settings!"