#!/bin/bash
# Quick install script for Malcolm's Dotfiles
set -euo pipefail

REPO_URL="https://github.com/Unintendedsideeffects/Dotfiles.git"
CONFIG_DIR="$HOME/.cfg"

echo "🚀 Installing Malcolm's Dotfiles..."

# Check if git is available
if ! command -v git >/dev/null 2>&1; then
    echo "❌ Git is required but not installed. Please install git first."
    exit 1
fi

# Backup existing .cfg if it exists
if [[ -d "$CONFIG_DIR" ]]; then
    echo "⚠️  Backing up existing .cfg directory..."
    mv "$CONFIG_DIR" "${CONFIG_DIR}.backup.$(date +%s)"
fi

# Clone the bare repository
echo "📥 Cloning dotfiles repository..."
git clone --bare "$REPO_URL" "$CONFIG_DIR"

# Set up the config alias temporarily
config() {
    /usr/bin/git --git-dir="$CONFIG_DIR" --work-tree="$HOME" "$@"
}

# Backup existing dotfiles that would conflict
echo "🔄 Checking for conflicting files..."
if config checkout 2>&1 | grep -E "\s+\." >/dev/null; then
    echo "⚠️  Backing up existing dotfiles..."
    mkdir -p "$HOME/.dotfiles-backup"
    config checkout 2>&1 | grep -E "\s+\." | awk '{print $1}' | \
        xargs -I{} sh -c 'mv "$HOME/{}" "$HOME/.dotfiles-backup/{}" 2>/dev/null || true'
fi

# Checkout the dotfiles
echo "✅ Installing dotfiles..."
config checkout

# Make scripts executable
chmod +x "$HOME/.dotfiles/bin/"* "$HOME/.dotfiles/shell/"* 2>/dev/null || true

# Source the config to get the config alias
source "$HOME/.dotfiles/cli/config.sh"

# Install shell configuration
echo "🐚 Installing shell configuration..."
"$HOME/.dotfiles/shell/install.sh"

# Run interactive bootstrap
echo "🎯 Starting interactive setup..."
echo "   - Select 'Install Packages' to get development tools"
echo "   - Select 'WSL Configuration Setup' if you're on WSL"
echo ""
read -p "Press Enter to continue with interactive setup..."

"$HOME/.dotfiles/bin/bootstrap.sh"

echo ""
echo "✨ Installation complete!"
echo ""
echo "💡 Next steps:"
echo "   - Restart your shell or run: source ~/.zshrc"
echo "   - Use 'config' command to manage your dotfiles"
echo "   - Run 'validate.sh' to verify your setup"
echo ""
echo "📚 Learn more: https://github.com/Unintendedsideeffects/Dotfiles"