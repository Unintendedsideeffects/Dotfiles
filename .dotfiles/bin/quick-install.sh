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
if ! checkout_output=$(config checkout 2>&1); then
    echo "⚠️  Some files already exist. Creating backup and forcing checkout..."
    backup_dir="$HOME/.dotfiles-backup.$(date +%s)"
    mkdir -p "$backup_dir"

    mapfile -t conflict_files < <(printf '%s\n' "$checkout_output" | grep -E "^\s+\." | awk '{print $1}')
    if [[ ${#conflict_files[@]} -eq 0 ]]; then
        echo "❌ Failed to determine conflicting files for backup."
        echo "$checkout_output"
        exit 1
    fi

    for path in "${conflict_files[@]}"; do
        if [[ -e "$HOME/$path" ]]; then
            mkdir -p "$backup_dir/$(dirname "$path")"
            mv "$HOME/$path" "$backup_dir/$path"
        fi
    done

    # Force checkout, overwriting existing files
    config checkout -f
    echo "✅ Dotfiles installed (existing files backed up to $backup_dir)"
else
    echo "✅ Dotfiles installed successfully"
fi

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
