# Malcolm's Dotfiles

Cross-platform dotfiles for Linux development environments. Works on Arch, Debian/Ubuntu, Proxmox, and WSL2.

## 🎉 NEW: Nix-based Configuration Available!

This repository now supports **declarative configuration management** using Nix and Home Manager! This provides:

- ✨ **Reproducible environments** - Same config, same result, every time
- 🔄 **Atomic updates** - Changes are applied atomically and can be rolled back
- 📦 **No dependency conflicts** - Nix manages dependencies independently
- 🎯 **Multi-environment support** - Easy switching between different configurations
- 🚀 **Modern package management** - Access to 80,000+ packages

### Quick Start with Nix

```bash
# Clone the repository
git clone https://github.com/Unintendedsideeffects/Dotfiles.git ~/Dotfiles
cd ~/Dotfiles

# Run the installer (will install Nix if needed)
./install-nix.sh

# Or manually install Home Manager
nix run home-manager/master -- switch --flake ~/Dotfiles#arch    # For Arch Linux
nix run home-manager/master -- switch --flake ~/Dotfiles#debian  # For Debian/Ubuntu
nix run home-manager/master -- switch --flake ~/Dotfiles#wsl     # For WSL
```

📖 **[Read the full Nix migration guide](NIX_MIGRATION.md)** for detailed instructions and documentation.

---

## Traditional Setup (Original Method)

You can still use the traditional installation method below if you prefer not to use Nix.

## Features

- **Universal**: Works on Arch, Debian/Ubuntu, Proxmox, and WSL2
- **Smart Detection**: Automatically configures for your environment
- **Interactive Bootstrap**: TUI for selecting components to install
- **Optimized Packages**: Curated package lists per environment
- **WSL Ready**: Special handling for WSL2 with Windows integration

## Quick Setup

**One command install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Unintendedsideeffects/Dotfiles/master/.dotfiles/bin/quick-install.sh | bash
```

**Or manual setup:**
```bash
git clone --bare https://github.com/Unintendedsideeffects/Dotfiles.git "$HOME/.cfg"
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
config checkout 2>&1 | grep -E "\s+\." | awk '{print $1}' | xargs -I{} mv {} {}.backup || true
config checkout
source "$HOME/.dotfiles/cli/config.sh"
"$HOME/.dotfiles/shell/install.sh"
"$HOME/.dotfiles/bin/bootstrap.sh"
```

## What You Get

**Packages automatically installed based on your environment:**
- **Development tools**: git, neovim, build tools, language runtimes
- **Modern CLI tools**: ripgrep, fd, fzf, bat, eza, zoxide, atuin
- **Shell setup**: zsh with smart completion and history
- **WSL integration**: Windows path integration, WSL utilities
- **X11 forwarding**: For remote GUI applications

**Environment-specific packages:**
- **Arch/Arch WSL**: Uses pacman, includes AUR build tools
- **Debian/Ubuntu/Ubuntu WSL**: Uses apt, includes build-essential
- **Proxmox**: Conservative package set for server environments

## Interactive Bootstrap

The bootstrap script provides a TUI menu to install:

1. **AUR Helper Setup** - Installs yay for AUR package management (Arch only)
2. **Package Installation** - Automatically detects your environment and installs appropriate packages
3. **WSL Configuration** - Fixes common WSL configuration issues (WSL only)
4. **Headless GUI Setup** - X11 forwarding for remote desktop (Arch only)
5. **Obsidian Headless** - Containerized Obsidian setup

## WSL2 Special Features

**Automatic WSL detection and configuration:**
- Fixes common `/etc/wsl.conf` issues (invalid key formats)
- Enables systemd support in WSL2
- Includes Windows path integration
- Adds WSL utilities (`wslu`) for Windows integration

**WSL-optimized package lists:**
- `arch-wsl.txt` - Arch WSL with WSL integration tools
- `debian-wsl.txt` - Ubuntu/Debian WSL with WSL integration tools

## Managing Your Dotfiles

After installation, use the `config` command for git operations:
```bash
config status           # Check dotfile changes
config add .file        # Add a new dotfile
config commit -m "msg"  # Commit changes
config push             # Push to remote
```

## Customization

- **Local settings**: Create `~/.zshrc.local` for machine-specific config
- **Additional packages**: Add to `.dotfiles/pkglists/*.txt` files
- **Environment tweaks**: Modify `.dotfiles/shell/zshrc.d/` files

## Manual Commands

If you prefer manual installation:
```bash
./.dotfiles/shell/install.sh      # Install shell configuration
./.dotfiles/bin/setup-aur.sh      # Install yay AUR helper (Arch only)
./.dotfiles/bin/setup-packages.sh # Install packages for your environment  
./.dotfiles/bin/setup-wsl.sh      # Configure WSL (WSL only)
./.dotfiles/bin/validate.sh       # Verify installation
```

## X11 Forwarding

For remote GUI applications:
1. Run `./.dotfiles/bin/setup-xforward.sh`
2. Connect with `ssh -X user@host`
3. Test with `xclock`

## Troubleshooting

**Common issues:**
- Make scripts executable: `chmod +x .dotfiles/bin/* .dotfiles/shell/*`
- WSL configuration errors: Run `./.dotfiles/bin/setup-wsl.sh`
- Missing packages: Check `.dotfiles/bin/validate.sh` output

**WSL-specific:**
- After WSL configuration changes: `wsl --shutdown` then restart
- Windows path issues: Check `.dotfiles/shell/zshrc.d/wsl.zsh`