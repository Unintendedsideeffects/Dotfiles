#!/bin/bash

# Dotfiles installation script
# Sets up symlinks and creates necessary directories

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

echo "Installing dotfiles from $DOTFILES_DIR to $HOME_DIR"

# Create necessary directories
mkdir -p "$HOME_DIR/.zshrc.d"

# Function to create symlink with backup
create_symlink() {
  local source="$1"
  local target="$2"
  
  if [[ -L "$target" ]]; then
    echo "Removing existing symlink: $target"
    rm "$target"
  elif [[ -f "$target" ]]; then
    echo "Backing up existing file: $target -> $target.backup"
    mv "$target" "$target.backup"
  fi
  
  echo "Creating symlink: $target -> $source"
  ln -sf "$source" "$target"
}

# Install zsh configuration
if [[ -f "$DOTFILES_DIR/.zshrc.new" ]]; then
  create_symlink "$DOTFILES_DIR/.zshrc.new" "$HOME_DIR/.zshrc"
fi

if [[ -f "$DOTFILES_DIR/zshrc.base" ]]; then
  create_symlink "$DOTFILES_DIR/zshrc.base" "$HOME_DIR/.zshrc.base"
fi

# Install zshrc.d fragments
for config in "$DOTFILES_DIR/zshrc.d"/*.zsh; do
  if [[ -f "$config" ]]; then
    filename=$(basename "$config")
    create_symlink "$config" "$HOME_DIR/.zshrc.d/$filename"
  fi
done

# Install other shell configurations
if [[ -f "$DOTFILES_DIR/.zprofile" ]]; then
  create_symlink "$DOTFILES_DIR/.zprofile" "$HOME_DIR/.zprofile"
fi

if [[ -f "$DOTFILES_DIR/.bashrc" ]]; then
  create_symlink "$DOTFILES_DIR/.bashrc" "$HOME_DIR/.bashrc"
fi

# Create .zshrc.local if it doesn't exist (for local overrides)
if [[ ! -f "$HOME_DIR/.zshrc.local" ]]; then
  echo "# Local zsh overrides (not versioned in git)" > "$HOME_DIR/.zshrc.local"
  echo "# Add machine-specific configurations here" >> "$HOME_DIR/.zshrc.local"
  echo "Created $HOME_DIR/.zshrc.local for local overrides"
fi

echo "Installation complete!"
echo ""
echo "Next steps:"
echo "1. Restart your shell or run: source ~/.zshrc"
echo "2. Check environment detection: echo \$IS_ARCH \$IS_ROCKY \$IS_WSL \$IS_CROSTINI"
echo "3. Add local overrides to ~/.zshrc.local (not versioned)"
echo "4. Symlink enterprise config if needed: ln -s ~/.dotfiles/shell/zshrc.d/enterprise.zsh ~/.zshrc.d/" 