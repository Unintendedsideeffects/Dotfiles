#!/bin/bash

# Dotfiles Push Script - Copies config files from repository to system
# This script pushes configuration files from the dotfiles repository
# to the user's home directory

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="$HOME"

echo "Pushing dotfiles from $DOTFILES_DIR to $HOME_DIR"

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

# Create necessary directories in home
mkdir -p "$HOME_DIR/.config"
mkdir -p "$HOME_DIR/bin"

# Copy .config directory contents
echo "Copying .config directory..."
if [[ -d "$DOTFILES_DIR/.config" ]]; then
    for dir in "$DOTFILES_DIR/.config"/*; do
        if [[ -d "$dir" ]]; then
            dirname=$(basename "$dir")
            copy_dir "$dir" "$HOME_DIR/.config/"
        fi
    done
fi

# Copy shell configuration files
echo "Copying shell configuration files..."
copy_file "$DOTFILES_DIR/shell/.bashrc" "$HOME_DIR/"
copy_file "$DOTFILES_DIR/shell/.zshrc" "$HOME_DIR/"
copy_file "$DOTFILES_DIR/shell/.xinitrc" "$HOME_DIR/"
copy_file "$DOTFILES_DIR/shell/.Xresources" "$HOME_DIR/"
copy_file "$DOTFILES_DIR/shell/.zprofile" "$HOME_DIR/"

# Copy other common dotfiles
echo "Copying other dotfiles..."
copy_file "$DOTFILES_DIR/.gitconfig" "$HOME_DIR/" 2>/dev/null || echo "No .gitconfig found"
copy_file "$DOTFILES_DIR/.gitignore_global" "$HOME_DIR/" 2>/dev/null || echo "No .gitignore_global found"

# Copy bin directory
if [[ -d "$DOTFILES_DIR/bin" ]]; then
    echo "Copying bin directory..."
    copy_dir "$DOTFILES_DIR/bin" "$HOME_DIR/"
fi

# Copy cli directory
if [[ -d "$DOTFILES_DIR/cli" ]]; then
    echo "Copying cli directory..."
    copy_dir "$DOTFILES_DIR/cli" "$HOME_DIR/"
fi

# Reload X resources if .Xresources was updated
if [[ -f "$HOME_DIR/.Xresources" ]]; then
    echo "Reloading X resources..."
    xrdb "$HOME_DIR/.Xresources"
fi

echo "Dotfiles push completed successfully!"
notify-send -t 3000 "Dotfiles" "Configuration files pushed successfully"