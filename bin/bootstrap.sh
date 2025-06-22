#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Create necessary directories
mkdir -p "$HOME/.config"

# List of configs to symlink
CONFIGS=(
    "git"
    "htop"
    "kitty"
    "sway"
    "rofi"
    "dunst"
    "gtk-3.0"
    "i3"
    "mpd"
    "nvim"
    "yabar"
    "picom"
    "ranger"
)

# Additional dotfiles to symlink
DOTFILES=(
    ".zshrc"
    ".gitconfig"
    ".xinitrc"
)

# Create symlinks for .config directories
for config in "${CONFIGS[@]}"; do
    if [ -d "$REPO_ROOT/.config/$config" ]; then
        echo "Creating symlink for $config..."
        ln -sf "$REPO_ROOT/.config/$config" "$HOME/.config/"
    fi
done

# Create symlink for starship.toml
if [ -f "$REPO_ROOT/.config/starship.toml" ]; then
    echo "Creating symlink for starship.toml..."
    ln -sf "$REPO_ROOT/.config/starship.toml" "$HOME/.config/starship.toml"
fi

# Create symlinks for dotfiles in home directory
for dotfile in "${DOTFILES[@]}"; do
    if [ -f "$REPO_ROOT/$dotfile" ]; then
        echo "Creating symlink for $dotfile..."
        ln -sf "$REPO_ROOT/$dotfile" "$HOME/$dotfile"
    fi
done

# Create symlink for .Xresources from shell directory
if [ -f "$REPO_ROOT/shell/.Xresources" ]; then
    echo "Creating symlink for .Xresources..."
    ln -sf "$REPO_ROOT/shell/.Xresources" "$HOME/.Xresources"
fi

# --- Font Improvement Steps ---
echo "Applying font improvement settings..."
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
    echo "Skipping system-wide font configuration. Run with sudo to apply."
fi

# Merge .Xresources, if available
if command -v xrdb >/dev/null 2>&1 && [ -f "$HOME/.Xresources" ]; then
    echo "Merging .Xresources..."
    xrdb -merge "$HOME/.Xresources"
fi

echo "Dotfiles have been bootstrapped! Please check the symlinks and configurations."
echo "For font changes to take full effect, you may need to reboot." 