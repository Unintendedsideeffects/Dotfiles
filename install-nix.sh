#!/usr/bin/env bash
# Nix Installation and Setup Script

set -e

echo "======================================"
echo "Nix-based Dotfiles Installation"
echo "======================================"
echo

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Nix is installed
if ! command -v nix &> /dev/null; then
    print_warn "Nix is not installed on this system"
    echo
    echo "Would you like to install Nix now? (y/n)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_info "Installing Nix..."

        # Install Nix with daemon
        sh <(curl -L https://nixos.org/nix/install) --daemon

        # Source nix
        if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
            . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
        fi

        print_info "Nix installed successfully!"
    else
        print_error "Nix is required to continue. Exiting."
        exit 1
    fi
fi

# Check if flakes are enabled
print_info "Checking Nix configuration..."

NIX_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nix"
NIX_CONF_FILE="$NIX_CONF_DIR/nix.conf"

mkdir -p "$NIX_CONF_DIR"

if ! grep -q "experimental-features.*flakes" "$NIX_CONF_FILE" 2>/dev/null; then
    print_info "Enabling Nix flakes..."
    echo "experimental-features = nix-command flakes" >> "$NIX_CONF_FILE"
    print_info "Flakes enabled!"
fi

# Detect the environment
print_info "Detecting your environment..."

PROFILE=""

if grep -qi microsoft /proc/version 2>/dev/null; then
    PROFILE="wsl"
    print_info "Detected: Windows Subsystem for Linux (WSL)"
elif [ -f /etc/pve/.version ]; then
    PROFILE="proxmox"
    print_info "Detected: Proxmox VE"
elif [ -f /etc/arch-release ]; then
    PROFILE="arch"
    print_info "Detected: Arch Linux"
elif [ -f /etc/debian_version ]; then
    PROFILE="debian"
    print_info "Detected: Debian/Ubuntu"
else
    print_warn "Could not auto-detect environment"
    PROFILE="minimal"
fi

# Ask if user wants GUI
if [[ "$PROFILE" != "wsl" && "$PROFILE" != "proxmox" && "$PROFILE" != "minimal" ]]; then
    echo
    echo "Do you want to install GUI components (window managers, desktop apps)? (y/n)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_info "GUI components will be installed"
        # The arch profile already includes GUI, so we're good
    fi
fi

# Ask for profile confirmation
echo
echo "Selected profile: $PROFILE"
echo "Available profiles: arch, debian, wsl, minimal, proxmox"
echo "Would you like to use a different profile? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Enter profile name:"
    read -r PROFILE
fi

# Get the dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_info "Using dotfiles directory: $DOTFILES_DIR"
print_info "Using profile: $PROFILE"

# Backup existing files that might conflict
print_info "Backing up existing configuration files..."

backup_file() {
    local file="$1"
    if [ -f "$file" ] && [ ! -L "$file" ]; then
        local backup="${file}.backup-$(date +%Y%m%d-%H%M%S)"
        print_warn "Backing up $file to $backup"
        mv "$file" "$backup"
    fi
}

backup_file "$HOME/.zshrc"
backup_file "$HOME/.bashrc"
backup_file "$HOME/.profile"

# Build and activate the configuration
print_info "Building Home Manager configuration..."
echo "This may take a while on the first run..."
echo

nix run home-manager/master -- switch --flake "$DOTFILES_DIR#$PROFILE" --impure

# Success message
echo
echo "======================================"
print_info "Installation complete!"
echo "======================================"
echo
echo "Next steps:"
echo "  1. Reload your shell: exec \$SHELL"
echo "  2. Review the configuration: cat $DOTFILES_DIR/NIX_MIGRATION.md"
echo "  3. Customize your setup by editing files in $DOTFILES_DIR/modules/"
echo "  4. Apply changes with: home-manager switch --flake $DOTFILES_DIR#$PROFILE"
echo
echo "Useful commands:"
echo "  nix-update     - Update flake inputs"
echo "  nix-switch     - Rebuild and activate configuration"
echo "  nix-clean      - Remove old generations"
echo "  nix-search     - Search for packages"
echo
print_info "Happy hacking!"
