#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif [[ -f /etc/arch-release ]]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

# Function to detect WSL
is_wsl() {
    [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version
}

# Function to install packages
install_packages() {
    local os="$1"
    local type="$2"
    local pkglist="pkglists/${os}-${type}.txt"

    if [[ ! -f "$pkglist" ]]; then
        echo -e "${RED}Error: Package list $pkglist not found${NC}"
        return 1
    fi

    echo -e "${YELLOW}Installing $type packages for $os...${NC}"
    
    case "$os" in
        "arch")
            while read -r pkg; do
                [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
                echo -e "${GREEN}Installing $pkg...${NC}"
                sudo pacman -S --needed --noconfirm "$pkg"
            done < "$pkglist"
            ;;
        "rocky"|"rhel"|"fedora")
            while read -r pkg; do
                [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
                echo -e "${GREEN}Installing $pkg...${NC}"
                sudo dnf install -y "$pkg"
            done < "$pkglist"
            ;;
        *)
            echo -e "${RED}Unsupported OS: $os${NC}"
            return 1
            ;;
    esac
}

# Main script
echo -e "${YELLOW}Starting bootstrap process...${NC}"

# Detect OS
OS=$(detect_os)
echo -e "${GREEN}Detected OS: $OS${NC}"

# Install CLI packages
install_packages "$OS" "cli"

# Install GUI packages if not in WSL
if ! is_wsl; then
    if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
        install_packages "$OS" "gui"
    else
        echo -e "${YELLOW}Skipping GUI packages (no display detected)${NC}"
    fi
else
    echo -e "${YELLOW}Skipping GUI packages (WSL detected)${NC}"
fi

# Install Powerlevel10k
if [[ ! -d "$HOME/powerlevel10k" ]]; then
    echo -e "${YELLOW}Installing Powerlevel10k...${NC}"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k"
fi

# Make scripts executable
echo -e "${YELLOW}Making scripts executable...${NC}"
chmod +x bin/*

echo -e "${GREEN}Bootstrap complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Run 'p10k configure' to set up your prompt"
echo "2. Restart your shell"
echo "3. Run './bin/test-dotfiles.sh' to verify the setup" 