#!/bin/bash

# Dotfiles Pull Script - Copies config files from system to repository
# This script pulls configuration files from the user's home directory
# into the dotfiles repository for version control

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="$HOME"

echo "Pulling dotfiles from $HOME_DIR to $DOTFILES_DIR"

# Create necessary directories if they don't exist
mkdir -p "$DOTFILES_DIR/.config"
mkdir -p "$DOTFILES_DIR/shell"

# Function to copy files with error handling
copy_file() {
    local src="$1"
    local dest="$2"
    
    if [[ -f "$src" ]]; then
        echo "Copying: $src -> $dest"
        cp "$src" "$dest"
    else
        echo "Warning: Source file not found: $src"
        return 1
    fi
}

# Function to copy directories with error handling
copy_dir() {
    local src="$1"
    local dest="$2"
    
    if [[ -d "$src" ]]; then
        echo "Copying directory: $src -> $dest"
        cp -r "$src" "$dest"
    else
        echo "Warning: Source directory not found: $src"
        return 1
    fi
}

# Copy .config directory contents
echo "Copying .config directory..."
if [[ -d "$HOME_DIR/.config" ]]; then
    for dir in "$HOME_DIR/.config"/*; do
        if [[ -d "$dir" ]]; then
            dirname=$(basename "$dir")
            copy_dir "$dir" "$DOTFILES_DIR/.config/"
        fi
    done
fi

# Copy shell configuration files
echo "Copying shell configuration files..."
copy_file "$HOME_DIR/.bashrc" "$DOTFILES_DIR/shell/"
copy_file "$HOME_DIR/.zshrc" "$DOTFILES_DIR/shell/"
copy_file "$HOME_DIR/.xinitrc" "$DOTFILES_DIR/shell/"
copy_file "$HOME_DIR/.Xresources" "$DOTFILES_DIR/shell/"
copy_file "$HOME_DIR/.zprofile" "$DOTFILES_DIR/shell/"

# Copy other common dotfiles
echo "Copying other dotfiles..."
copy_file "$HOME_DIR/.gitconfig" "$DOTFILES_DIR/" 2>/dev/null || echo "No .gitconfig found"
copy_file "$HOME_DIR/.gitignore_global" "$DOTFILES_DIR/" 2>/dev/null || echo "No .gitignore_global found"

# Copy bin directory (if it exists in home)
if [[ -d "$HOME_DIR/bin" ]]; then
    echo "Copying bin directory..."
    copy_dir "$HOME_DIR/bin" "$DOTFILES_DIR/"
fi

echo "Dotfiles pull completed successfully!"
notify-send -t 3000 "Dotfiles" "Configuration files pulled successfully"