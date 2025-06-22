#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

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

# Function to detect Crostini
is_crostini() {
    [[ -e /dev/cros_guest ]]
}

# Function to install packages
install_packages() {
    local os="$1"
    local type="$2"
    local pkglist="$REPO_ROOT/pkglists/${os}-${type}.txt"

    if [[ ! -f "$pkglist" ]]; then
        echo -e "${RED}Error: Package list $pkglist not found${NC}"
        return 1
    fi

    echo -e "${YELLOW}Installing $type packages for $os...${NC}"

    case "$os" in
        "arch")
            AUR_HELPER=""
            if command -v yay &> /dev/null; then
                AUR_HELPER="yay"
            elif command -v paru &> /dev/null; then
                AUR_HELPER="paru"
            fi

            while read -r pkg; do
                [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
                echo -e "${GREEN}Installing $pkg...${NC}"
                if [[ -n "$AUR_HELPER" ]]; then
                    "$AUR_HELPER" -S --needed --noconfirm "$pkg" || true
                else
                    sudo pacman -S --needed --noconfirm "$pkg" || true
                fi
            done < "$pkglist"
            ;;
        "rocky"|"rhel"|"fedora")
            while read -r pkg; do
                [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
                echo -e "${GREEN}Installing $pkg...${NC}"
                sudo dnf install -y "$pkg" || true
            done < "$pkglist"
            ;;
        *)
            echo -e "${RED}Unsupported OS: $os${NC}"
            return 1
            ;;
    esac
}

symlink_configs() {
    echo -e "${YELLOW}Creating symlinks...${NC}"
    # Create necessary directories
    mkdir -p "$HOME/.config"

    # List of configs to symlink
    CONFIGS=(
        "git" "htop" "kitty" "sway" "rofi" "dunst"
        "gtk-3.0" "i3" "mpd" "nvim" "yabar" "picom" "ranger"
    )

    # Additional dotfiles to symlink
    DOTFILES=(
        ".zshrc" ".gitconfig" ".xinitrc"
    )

    # Create symlinks for .config directories
    for config in "${CONFIGS[@]}"; do
        if [ -d "$REPO_ROOT/.config/$config" ]; then
            echo -e "${GREEN}Creating symlink for $config...${NC}"
            ln -sf "$REPO_ROOT/.config/$config" "$HOME/.config/"
        fi
    done

    # Create symlink for starship.toml
    if [ -f "$REPO_ROOT/.config/starship.toml" ]; then
        echo -e "${GREEN}Creating symlink for starship.toml...${NC}"
        ln -sf "$REPO_ROOT/.config/starship.toml" "$HOME/.config/starship.toml"
    fi

    # Create symlinks for dotfiles in home directory
    for dotfile in "${DOTFILES[@]}"; do
        if [ -f "$REPO_ROOT/$dotfile" ]; then
            echo -e "${GREEN}Creating symlink for $dotfile...${NC}"
            ln -sf "$REPO_ROOT/$dotfile" "$HOME/$dotfile"
        fi
    done

    # Create symlink for .Xresources from shell directory
    if [ -f "$REPO_ROOT/.dotfiles/shell/.Xresources" ]; then
        echo -e "${GREEN}Creating symlink for .Xresources...${NC}"
        ln -sf "$REPO_ROOT/.dotfiles/shell/.Xresources" "$HOME/.Xresources"
    fi
    echo -e "${GREEN}Symlinks created.${NC}"
}

configure_fonts() {
    echo -e "${YELLOW}Applying font improvement settings...${NC}"
    if [ "$(id -u)" -eq 0 ]; then
        echo "Running system-wide font configuration steps..."

        # Create symbolic links for font rendering
        ln -sf /usr/share/fontconfig/conf.avail/10-sub-pixel-rgb.conf /etc/fonts/conf.d/
        ln -sf /usr/share/fontconfig/conf.avail/10-hinting-slight.conf /etc/fonts/conf.d/
        ln -sf /usr/share/fontconfig/conf.avail/11-lcdfilter-default.conf /etc/fonts/conf.d/

        # Edit freetype2.sh
        FREETYPE_CONFIG="/etc/profile.d/freetype2.sh"
        if [ -f "$FREETYPE_CONFIG" ]; then
            echo "Updating freetype2.sh..."
            # Uncomment and set the interpreter version
            sed -i 's/^#\(export FREETYPE_PROPERTIES=\).*/\1"truetype:interpreter-version=40"/' "$FREETYPE_CONFIG"
        fi

        # Refresh font cache
        echo "Refreshing font cache..."
        fc-cache -fv

        echo "System-wide font configuration applied."
    else
        echo -e "${YELLOW}Skipping system-wide font configuration. Run with sudo to apply.${NC}"
    fi
}

merge_xresources() {
    if command -v xrdb >/dev/null 2>&1 && [ -f "$HOME/.Xresources" ]; then
        echo -e "${YELLOW}Merging .Xresources...${NC}"
        xrdb -merge "$HOME/.Xresources"
    fi
}

install_starship() {
    if ! command -v starship &> /dev/null; then
        echo -e "${YELLOW}Installing Starship...${NC}"
        if command -v pacman &> /dev/null; then
            sudo pacman -S --needed --noconfirm starship
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y starship
        else
            echo -e "${YELLOW}Could not find a package manager to install Starship. Installing from script...${NC}"
            curl -sS https://starship.rs/install.sh | sh -s -- -y
        fi
    else
        echo -e "${GREEN}Starship is already installed.${NC}"
    fi
}

install_aur_helper() {
    # Check for existing AUR helpers
    if command -v yay &> /dev/null || command -v paru &> /dev/null; then
        echo -e "${GREEN}AUR helper already installed.${NC}"
        return
    fi

    echo -e "${YELLOW}No AUR helper (like yay or paru) found.${NC}"
    read -p "Do you want to install yay? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installing yay...${NC}"
        
        # Dependencies for building AUR packages
        echo -e "${YELLOW}Ensuring git and base-devel are installed...${NC}"
        sudo pacman -S --needed --noconfirm git base-devel
        
        # Create a temporary directory for building
        BUILD_DIR=$(mktemp -d -p "/tmp" yay-build.XXXXXX)
        
        # Clone, build, and install yay
        echo -e "${YELLOW}Cloning yay from AUR...${NC}"
        if git clone https://aur.archlinux.org/yay.git "$BUILD_DIR"; then
            (
                cd "$BUILD_DIR" || exit
                echo -e "${YELLOW}Building and installing yay...${NC}"
                makepkg -si --noconfirm
            )
        else
            echo -e "${RED}Failed to clone yay repository.${NC}"
            rm -rf "$BUILD_DIR"
            return 1
        fi

        # Clean up
        echo -e "${YELLOW}Cleaning up...${NC}"
        rm -rf "$BUILD_DIR"
        
        if command -v yay &> /dev/null; then
            echo -e "${GREEN}yay installed successfully.${NC}"
        else
            echo -e "${RED}Failed to install yay.${NC}"
            return 1
        fi
    fi
}

setup_package_manager_configs() {
    echo -e "${YELLOW}Setting up optimized package manager configurations...${NC}"
    
    # Check if configuration files exist
    if [[ ! -f "$REPO_ROOT/.config/pacman/pacman.conf" ]]; then
        echo -e "${RED}Package manager configs not found, skipping setup${NC}"
        return
    fi

    # Backup existing configurations
    echo -e "${YELLOW}Backing up existing configurations...${NC}"
    if [[ -f "/etc/pacman.conf" ]]; then
        sudo cp /etc/pacman.conf /etc/pacman.conf.backup
        echo -e "${GREEN}Backed up /etc/pacman.conf${NC}"
    fi

    if [[ -f "/etc/makepkg.conf" ]]; then
        sudo cp /etc/makepkg.conf /etc/makepkg.conf.backup
        echo -e "${GREEN}Backed up /etc/makepkg.conf${NC}"
    fi

    # Apply optimized configurations
    echo -e "${YELLOW}Applying optimized pacman configuration...${NC}"
    sudo cp "$REPO_ROOT/.config/pacman/pacman.conf" /etc/pacman.conf

    echo -e "${YELLOW}Applying optimized makepkg configuration...${NC}"
    sudo cp "$REPO_ROOT/.config/pacman/makepkg.conf" /etc/makepkg.conf

    # Set up yay configuration
    echo -e "${YELLOW}Setting up yay configuration...${NC}"
    mkdir -p ~/.config/yay
    cp "$REPO_ROOT/.config/yay/config.json" ~/.config/yay/config.json

    # Install ccache if not present
    if ! command -v ccache &> /dev/null; then
        echo -e "${YELLOW}Installing ccache for faster builds...${NC}"
        sudo pacman -S --needed --noconfirm ccache
    else
        echo -e "${GREEN}ccache already installed${NC}"
    fi

    # Create makepkg cache directories
    echo -e "${YELLOW}Creating makepkg cache directories...${NC}"
    mkdir -p ~/.cache/makepkg/{packages,sources,srcpackages,logs}

    echo -e "${GREEN}Package manager configuration complete!${NC}"
    echo -e "${GREEN}Optimizations applied:${NC}"
    echo "  • Pacman: 8 parallel downloads, color output, progress bars"
    echo "  • Makepkg: Multi-core builds, ccache, LTO optimization"
    echo "  • Yay: Safety features and performance settings"
    echo "  • Cache: User-specific build directories created"
}

main() {
    echo -e "${YELLOW}Starting bootstrap process...${NC}"

    # Detect OS
    OS=$(detect_os)
    echo -e "${GREEN}Detected OS: $OS${NC}"

    if [[ "$OS" == "arch" ]]; then
        setup_package_manager_configs
        install_aur_helper
        if is_crostini; then
            echo -e "${GREEN}Detected Crostini environment. Installing Crostini packages...${NC}"
            install_packages "$OS" "crostini"
        fi
    fi

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

    symlink_configs

    if ! is_wsl; then
      configure_fonts
      merge_xresources
    fi

    install_starship

    # Make scripts executable
    echo -e "${YELLOW}Making scripts executable...${NC}"
    chmod +x "$SCRIPT_DIR"/*

    echo -e "${GREEN}Bootstrap complete!${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Restart your shell to see the new prompt"
    echo "2. Run '$SCRIPT_DIR/test-dotfiles.sh' to verify the setup"
    if [[ "$OS" == "arch" ]]; then
        echo "3. Package manager optimizations are now active (pacman/yay/makepkg)"
        echo "4. For font changes to take full effect, you may need to reboot."
    else
        echo "3. For font changes to take full effect, you may need to reboot."
    fi
}

main "$@" 