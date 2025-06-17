#!/bin/bash

# Script to copy configs from ~/.config to the repository's .config directory
# Usage: ./copy-configs.sh

set -e  # Exit on error

# List of configs to copy
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
)

# Create destination directories if they don't exist
for config in "${CONFIGS[@]}"; do
    if [ ! -d ".config/$config" ]; then
        echo "Creating .config/$config"
        mkdir -p ".config/$config"
    fi
done

# Copy configs
for config in "${CONFIGS[@]}"; do
    if [ -d "$HOME/.config/$config" ]; then
        echo "Copying $config..."
        cp -r "$HOME/.config/$config/"* ".config/$config/" 2>/dev/null || true
    else
        echo "Warning: $HOME/.config/$config does not exist"
    fi
done

echo "Done! Please review the copied configs and commit them." 