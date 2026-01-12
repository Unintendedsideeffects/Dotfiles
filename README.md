# Malcolm's Dotfiles - Full NixOS Edition

**Declarative, reproducible dotfiles and system configuration for NixOS and other Linux distributions.**

This repository provides both **full NixOS system configurations** and **Home Manager-only** setups for non-NixOS distributions.

## 🌟 Features

- **Full NixOS Support**: Complete system configuration with modular architecture
- **Home Manager Integration**: User-level packages and configurations
- **Multi-Environment**: Works on NixOS, Arch, Debian/Ubuntu, Proxmox, and WSL2
- **Declarative**: Everything defined in Nix for reproducibility
- **Modular**: Easy to customize and extend
- **Window Managers**: i3 (X11) and Sway (Wayland) configurations
- **Modern CLI Tools**: ripgrep, fd, fzf, bat, eza, zoxide, starship, and more

## 📋 Quick Start

### For Full NixOS Installation

If you want to install NixOS with this configuration:

```bash
# Follow the detailed guide
see NIXOS_INSTALLATION.md
```

**TL;DR for existing NixOS:**
```bash
sudo git clone --branch nixos-full https://github.com/Unintendedsideeffects/Dotfiles.git /etc/nixos-dotfiles
cd /etc/nixos-dotfiles
sudo cp /etc/nixos/hardware-configuration.nix nixos/
sudo nixos-rebuild switch --flake .#nixos-desktop
```

### For Home Manager Only (Non-NixOS)

If you're on Arch, Debian, Ubuntu, or other distributions:

```bash
# Install Nix
sh <(curl -L https://nixos.org/nix/install) --daemon

# Enable flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Clone repository
git clone --branch nixos-full https://github.com/Unintendedsideeffects/Dotfiles.git ~/Dotfiles
cd ~/Dotfiles

# Apply configuration (choose your profile)
nix run home-manager/master -- switch --flake ~/Dotfiles#arch
# or: #debian, #wsl, #minimal, #proxmox
```

## 🚀 What's New in nixos-full Branch

This branch provides **complete NixOS system configuration** in addition to Home Manager:

### Full NixOS System Configuration
- **Modular architecture**: Boot, networking, desktop, services, users
- **Multiple profiles**: Desktop, laptop, server, WSL
- **Hardware abstraction**: Easy hardware configuration management
- **Integrated Home Manager**: System + user configuration in one place

### Repository Structure

```
Dotfiles/
├── flake.nix                      # Main flake with all configurations
├── home.nix                       # Home Manager entry point
├── NIXOS_INSTALLATION.md          # Full NixOS installation guide
├── NIX_MIGRATION.md               # Home Manager migration guide
│
├── nixos/                         # NixOS system configuration
│   ├── configuration.nix          # Main system config
│   ├── hardware-configuration.nix.example
│   ├── modules/                   # System modules
│   │   ├── boot.nix              # Bootloader configuration
│   │   ├── networking.nix        # Network and Bluetooth
│   │   ├── desktop.nix           # Desktop environment
│   │   ├── services.nix          # System services
│   │   └── users.nix             # User management
│   └── packages/
│       └── dotfiles-scripts.nix  # Custom scripts as Nix package
│
├── modules/                       # Home Manager modules
│   ├── packages.nix              # User packages
│   ├── shell.nix                 # Shell configuration
│   ├── git.nix                   # Git configuration
│   ├── services.nix              # User services
│   ├── scripts.nix               # Script management
│   ├── programs/                 # Program configurations
│   │   ├── neovim.nix
│   │   ├── tmux.nix
│   │   ├── starship.nix
│   │   ├── i3.nix
│   │   ├── sway.nix
│   │   └── ...
│   └── environments/             # Environment-specific configs
│       ├── arch.nix
│       ├── debian.nix
│       ├── wsl.nix
│       ├── minimal.nix
│       └── gui.nix
│
├── .config/                       # Traditional dotfiles
│   ├── nvim/
│   ├── i3/
│   ├── sway/
│   ├── starship.toml
│   └── ...
│
└── .dotfiles/                     # Legacy scripts and utilities
    ├── bin/                       # Utility scripts
    ├── cli/                       # Shell helpers
    └── lib/                       # Shared libraries
```

## 📦 Available Configurations

### NixOS System Configurations

For full NixOS installations:

- **`nixos-desktop`**: Full desktop with i3/Sway, audio, Bluetooth
- **`nixos-laptop`**: Desktop + power management (TLP, thermald)
- **`nixos-server`**: Headless server configuration
- **`nixos-wsl`**: Windows Subsystem for Linux

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos-desktop
```

### Home Manager Configurations

For any Linux distribution (non-NixOS):

- **`arch`**: Arch Linux with GUI support
- **`debian`**: Debian/Ubuntu configuration
- **`wsl`**: Windows Subsystem for Linux
- **`minimal`**: Minimal headless configuration
- **`proxmox`**: Proxmox server configuration

```bash
home-manager switch --flake ~/Dotfiles#arch
```

## 🛠️ Customization

### System-Level (NixOS)

Edit `flake.nix` to customize system configuration:

```nix
nixos-dotfiles = {
  boot.enableSystemdBoot = true;
  networking.hostName = "my-nixos";
  desktop = {
    enable = true;
    windowManager = "both";  # i3 and sway
  };
  services = {
    enableDocker = true;
    enableVirtualization = true;
  };
};
```

### User-Level (All Systems)

Edit module files in `modules/`:

```bash
# Add packages
vim modules/packages.nix

# Configure shell
vim modules/shell.nix

# Configure git
vim modules/git.nix

# Rebuild
home-manager switch --flake ~/Dotfiles#arch
```

## 🔧 Common Tasks

### Update Everything

```bash
# NixOS system
sudo nixos-rebuild switch --flake /etc/nixos#nixos-desktop --update-input nixpkgs

# Home Manager only
cd ~/Dotfiles
nix flake update
home-manager switch --flake .#arch
```

### Add a New Package

```bash
# Edit packages.nix
vim ~/Dotfiles/modules/packages.nix

# Add your package to the appropriate list
# Then rebuild
home-manager switch --flake ~/Dotfiles#arch
```

### Rollback Changes

```bash
# NixOS system
sudo nixos-rebuild switch --rollback

# Home Manager
home-manager generations
home-manager switch --switch-generation <number>
```

### Clean Old Generations

```bash
# NixOS system
sudo nix-collect-garbage -d

# Home Manager
home-manager expire-generations "-7 days"
nix-collect-garbage
```

## 📚 Documentation

- **[NIXOS_INSTALLATION.md](NIXOS_INSTALLATION.md)**: Complete NixOS installation guide
- **[NIX_MIGRATION.md](NIX_MIGRATION.md)**: Migrating to Home Manager from traditional dotfiles
- **[NIX_ADVANCED.md](NIX_ADVANCED.md)**: Advanced Nix configuration topics

## 🎯 Use Cases

### Fresh NixOS Install
Perfect for:
- New machine setup with complete system config
- Reproducible development environments
- Multi-machine synchronization

### Existing Non-NixOS System
Great for:
- User-level package management without root
- Consistent dotfiles across distributions
- Trying NixOS ecosystem before full commitment

### WSL Development
Ideal for:
- Windows developers using WSL2
- Consistent dev environment on Windows
- Integration with Windows tools

## 🔑 Key Components

### System Services (NixOS)
- PipeWire audio
- NetworkManager
- Bluetooth (bluez)
- Printing (CUPS)
- Docker (optional)
- libvirt/QEMU (optional)

### Desktop Environment
- **Window Managers**: i3 (X11), Sway (Wayland)
- **Display Manager**: LightDM (configurable)
- **Terminal**: kitty, ghostty, alacritty
- **Launcher**: rofi, wofi
- **Notifications**: dunst, mako
- **Bar**: i3status, waybar

### Development Tools
- Neovim (with LSP support)
- Git with enhanced configuration
- tmux, zellij
- Languages: Python, Go, Rust, Node.js
- Docker, kubectl, k9s
- Language servers: nil, rust-analyzer, etc.

### Modern CLI Tools
- **File navigation**: ranger, yazi
- **Search**: ripgrep, fd, fzf
- **Display**: bat, eza
- **System monitoring**: htop, btop, bottom
- **Shell**: zsh with starship prompt
- **History**: atuin

## 🆚 Master vs nixos-full Branch

### Master Branch
- Home Manager only
- Hybrid Nix + traditional approach
- Works on any distribution
- User-level configuration

### nixos-full Branch (This Branch)
- Full NixOS system configuration
- Complete declarative system
- Home Manager integrated
- System + user configuration
- Modular architecture
- Multiple system profiles

## 🤝 Contributing

Contributions are welcome! This is a personal dotfiles repository, but:

- Bug fixes are always appreciated
- Suggestions for improvements welcome
- Share your own customizations via issues/discussions

## 📝 License

This repository is licensed under MIT. Feel free to use, modify, and share.

## 🙏 Acknowledgments

- NixOS community for the amazing ecosystem
- Home Manager maintainers
- All the open-source tools that make this possible

## 💬 Support & Discussion

- **Issues**: [GitHub Issues](https://github.com/Unintendedsideeffects/Dotfiles/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Unintendedsideeffects/Dotfiles/discussions)
- **NixOS Discourse**: [discourse.nixos.org](https://discourse.nixos.org/)

---

**Note**: The master branch contains the hybrid approach with partial Nix support. Switch to `nixos-full` branch for complete NixOS system configuration.

```bash
# Switch to nixos-full branch
git checkout nixos-full

# Or clone directly
git clone --branch nixos-full https://github.com/Unintendedsideeffects/Dotfiles.git
```
