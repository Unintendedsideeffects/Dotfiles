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

# Handle existing dotfiles
echo "🔄 Installing dotfiles (will overwrite existing files)..."
if ! config checkout 2>/dev/null; then
    echo "⚠️  Some files already exist. Creating backup and forcing checkout..."
    mkdir -p "$HOME/.dotfiles-backup.$(date +%s)"
    
    # Force checkout, overwriting existing files
    config checkout -f
    echo "✅ Dotfiles installed (existing files backed up)"
else
    echo "✅ Dotfiles installed successfully"
fi

# Make scripts executable
chmod +x "$HOME/.dotfiles/bin/"* "$HOME/.dotfiles/shell/"* 2>/dev/null || true

# Source the config to get the config alias
source "$HOME/.dotfiles/cli/config.sh"

# Configure git user settings
echo ""
echo "⚙️  Git Configuration"

# Try to get git config from environment or existing git config
git_username="${GIT_USER_NAME:-$(git config --global user.name 2>/dev/null || echo "")}"
git_email="${GIT_USER_EMAIL:-$(git config --global user.email 2>/dev/null || echo "")}"

# Only prompt if not already set
if [[ -z "$git_username" ]]; then
    echo "Please enter your git user information:"
    echo ""
    read -p "Git username: " git_username
    while [[ -z "$git_username" ]]; do
        echo "Username cannot be empty."
        read -p "Git username: " git_username
    done
else
    echo "Using git username from environment: $git_username"
fi

if [[ -z "$git_email" ]]; then
    if [[ -z "$GIT_USER_NAME" ]]; then
        echo "Please enter your git user information:"
        echo ""
    fi
    read -p "Git email: " git_email
    while [[ -z "$git_email" ]]; do
        echo "Email cannot be empty."
        read -p "Git email: " git_email
    done
else
    echo "Using git email from environment: $git_email"
fi

# Create .gitconfig.local with user settings
echo ""
echo "📝 Creating ~/.gitconfig.local..."
cat > "$HOME/.gitconfig.local" <<EOF
# Local Git Configuration
# This file was automatically created during dotfiles setup
# Edit this file to update your git user information

[user]
	name = $git_username
	email = $git_email

# Optional: Configure GPG signing
# [commit]
# 	gpgsign = true
# [user]
# 	signingkey = YOUR_GPG_KEY_ID

# Optional: Add any other local overrides here
EOF

echo "✅ Git configuration saved to ~/.gitconfig.local"
echo ""

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