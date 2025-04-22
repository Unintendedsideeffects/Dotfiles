# Arch Linux on Crostini Configuration

A comprehensive guide and configuration for running Arch Linux in Crostini on a Google Pixelbook. This repository contains both installation instructions and configuration files for setting up a development environment in Chrome OS's Linux container.

## Overview

This repository provides:
- Step-by-step installation guide for Arch Linux in Crostini
- Configuration files for a development environment
- Package management setup
- System configuration for Chrome OS integration
- Development tools and utilities setup

## Prerequisites

- Google Pixelbook with Linux (Beta) enabled in Chrome OS settings
- Terminal access to Chrome OS (crosh)
- The default Debian container should be set up first (we'll replace it)

## Installation Guide

### 1. Initial Container Setup

1. Open Chrome OS terminal (`Ctrl+Alt+t`)
2. Enter termina:
   ```bash
   vsh termina
   ```
3. Configure LXC remotes:
   ```bash
   lxc remote remove images
   lxc remote add images https://images.lxd.canonical.com/ --protocol=simplestreams
   ```
4. Create Arch container:
   ```bash
   lxc launch images:archlinux arch --config security.privileged=true
   ```
5. Start and enter container:
   ```bash
   lxc start arch
   lxc exec arch -- bash
   ```

### 2. System Configuration

1. Update system and install base tools:
   ```bash
   sudo pacman -Syu
   sudo pacman -Sy --needed git base-devel
   ```

2. Configure network if needed:
   ```bash
   sudo systemctl disable systemd-networkd
   sudo systemctl disable systemd-resolved
   sudo pacman -S dhclient
   sudo dhclient eth0
   sudo systemctl enable dhclient@eth0
   sudo systemctl start dhclient@eth0
   ```

3. Install AUR helper:
   ```bash
   mkdir -p /tmp/yay_install
   cd /tmp/yay_install
   git clone https://aur.archlinux.org/yay.git
   cd yay
   makepkg -si
   ```

### 3. Chrome OS Integration

1. Fix Chrome OS integration:
   ```bash
   sudo mkdir -p /usr/lib/openssh/
   sudo ln -s /usr/lib/ssh/sftp-server /usr/lib/openssh/sftp-server
   sudo setcap cap_net_raw+ep /usr/bin/ping
   ```

2. Install Crostini tools:
   ```bash
   yay -S cros-container-guest-tools-git wayland xorg-xwayland
   ```

## Configuration Files

This repository includes the following configuration files:

```
.
├── .config/          # Application configurations
├── .devcontainer/    # VS Code devcontainer configuration
├── .scripts/         # Custom shell scripts
├── .bashrc          # Bash configuration
├── .xbindkeysrc     # X11 key bindings
├── .xinitrc         # X11 initialization
├── .Xresources      # X11 resources
├── .zprofile        # ZSH profile configuration
├── .zshrc           # ZSH configuration
└── packages.txt     # List of installed packages
```

## Development Environment Setup

### 1. Shell Configuration

```bash
# Install ZSH and Powerline
yay -S zsh powerline powerline-fonts

# Configure Powerline for ZSH
echo 'powerline-daemon -q
. /usr/share/powerline/bindings/zsh/powerline.zsh' >> ~/.zshrc

# Set ZSH as default shell
chsh -s /usr/bin/zsh
```

### 2. Development Tools

```bash
# Install essential development tools
yay -S neovim cursor-bin-patched obsidian

# Configure Git
git config --global user.name "$(whoami)"
git config --global user.email "$(whoami)@pixelbook"
git config --global init.defaultBranch main
git config --global core.editor "nvim"
```

### 3. System Utilities

```bash
# Install system utilities
yay -S neofetch catimg feh chafa imagemagick ghostscript ranger zathura zathura-pdf-mupdf
```

### 4. Modern CLI Tools

This configuration includes several modern CLI tools that enhance productivity:

```bash
# Install modern CLI tools
yay -S starship fzf exa bat ripgrep zoxide
```

These tools provide the following improvements:

- **Starship**: A blazing-fast, customizable cross-shell prompt
- **fzf**: A command-line fuzzy finder for interactive filtering
- **exa**: A modern replacement for `ls` with icons and better formatting
- **bat**: A `cat` clone with syntax highlighting and Git integration
- **ripgrep**: A faster alternative to `grep` with better defaults
- **zoxide**: A smarter `cd` command that learns your habits

The configuration automatically sets up aliases and integrations for these tools in your shell. For example:
- `ls` is aliased to `exa` with icons and directory-first sorting
- `cat` is aliased to `bat` with syntax highlighting
- `grep` is aliased to `ripgrep` for faster searching
- `cd` is aliased to `zoxide` for intelligent directory jumping

## Font Setup for Powerline/Nerd Font Symbols

To ensure proper rendering of Powerline symbols and icons in terminals and editors:

1. Install the required fonts:
   ```bash
   # On Arch Linux
   yay -S ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols
   
   # On Ubuntu/Debian
   apt install fonts-jetbrains-mono-nerd fonts-nerd-fonts-symbols
   
   # On macOS
   brew tap homebrew/cask-fonts
   brew install --cask font-jetbrains-mono-nerd-font font-symbols-only-nerd-font
   ```

2. Update Cursor settings:
   ```json
   {
     "editor.fontFamily": "'JetBrainsMonoNL Nerd Font', 'Symbols Nerd Font Mono', monospace",
     "terminal.integrated.fontFamily": "'JetBrainsMonoNL Nerd Font', 'Symbols Nerd Font Mono', monospace",
     "editor.fontLigatures": true,
     "terminal.integrated.fontLigatures": true
   }
   ```

3. Clear font cache and restart:
   ```bash
   # Rebuild font cache
   fc-cache -f -v
   
   # Restart your terminal/editor
   ```

4. Verify installation:
   ```bash
   # Test Powerline symbols
   echo -e "\ue0b0 \ue0b1 \ue0b2 \ue0b3"
   ```
## Troubleshooting

### Common Issues

1. **Apps Not Opening (Infinite Spinner)**
   ```bash
   # In termina:
   lxc stop penguin
   lxc start penguin
   ```

2. **Audio Issues**
   ```bash
   mkdir -p ~/.config/pulse
   cp -r /etc/skel/.config/pulse ~/.config/
   ```

3. **Firefox Performance**
   ```bash
   MOZ_ENABLE_WAYLAND=1 firefox
   ```

4. **Network Issues**
   - Check `ip -4 a show dev eth0`
   - Verify DHCP client is running
   - Ensure systemd networking is disabled

## Making Arch the Default Container

To make Arch the default container:

1. Exit to termina:
   ```bash
   exit
   ```

2. Stop and rename containers:
   ```bash
   lxc stop --force penguin
   lxc stop --force arch
   lxc rename penguin debian
   lxc rename arch penguin
   lxc start penguin
   ```