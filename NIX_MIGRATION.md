# Nix Migration Guide

This repository has been migrated to use Nix and Home Manager for declarative dotfiles and package management. This provides several benefits:

- **Declarative configuration**: All packages and configurations are defined in code
- **Reproducibility**: Same configuration produces the same environment
- **Atomic updates**: Changes are applied atomically and can be rolled back
- **Multi-environment support**: Easy switching between different configurations
- **No dependency conflicts**: Nix manages dependencies independently

## Prerequisites

1. **Install Nix** (if not already installed):
   ```bash
   sh <(curl -L https://nixos.org/nix/install) --daemon
   ```

2. **Enable Nix Flakes**:
   ```bash
   mkdir -p ~/.config/nix
   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
   ```

3. **Install Home Manager** (done automatically via flake):
   ```bash
   # Home Manager will be installed when you build the configuration
   ```

## Quick Start

### 1. Clone the repository (if not already done)

```bash
git clone https://github.com/Unintendedsideeffects/Dotfiles.git ~/Dotfiles
cd ~/Dotfiles
```

### 2. Choose your configuration profile

The flake provides several pre-configured profiles:

- **arch**: Arch Linux desktop with GUI support
- **debian**: Debian/Ubuntu system
- **wsl**: Windows Subsystem for Linux
- **minimal**: Minimal headless configuration
- **proxmox**: Proxmox server configuration

### 3. Build and activate your configuration

```bash
# For Arch Linux with GUI
nix run home-manager/master -- switch --flake ~/Dotfiles#arch

# For Debian/Ubuntu
nix run home-manager/master -- switch --flake ~/Dotfiles#debian

# For WSL
nix run home-manager/master -- switch --flake ~/Dotfiles#wsl

# For minimal/headless systems
nix run home-manager/master -- switch --flake ~/Dotfiles#minimal

# For Proxmox servers
nix run home-manager/master -- switch --flake ~/Dotfiles#proxmox
```

### 4. Reload your shell

```bash
exec $SHELL
```

## Configuration Structure

```
Dotfiles/
├── flake.nix                    # Main entry point, defines outputs
├── home.nix                     # Home Manager configuration
├── modules/                     # Modular configuration
│   ├── packages.nix            # Package declarations
│   ├── shell.nix               # Shell (zsh/bash) configuration
│   ├── git.nix                 # Git configuration
│   ├── services.nix            # Systemd services
│   ├── programs/               # Program-specific configs
│   │   ├── default.nix         # Imports all program modules
│   │   ├── neovim.nix          # Neovim configuration
│   │   ├── tmux.nix            # Tmux configuration
│   │   ├── starship.nix        # Starship prompt
│   │   ├── terminal.nix        # Terminal emulators
│   │   ├── yazi.nix            # Yazi file manager
│   │   └── ranger.nix          # Ranger file manager
│   └── environments/           # Environment-specific modules
│       ├── arch.nix            # Arch Linux specific
│       ├── debian.nix          # Debian/Ubuntu specific
│       ├── wsl.nix             # WSL specific
│       ├── proxmox.nix         # Proxmox specific
│       ├── minimal.nix         # Minimal configuration
│       └── gui.nix             # GUI components (sway, i3, etc.)
└── nixos/                       # Optional NixOS system configuration
    └── configuration.nix        # NixOS config (if using NixOS)
```

## Making Changes

### Adding Packages

Edit `modules/packages.nix` and add packages to the appropriate section:

```nix
home.packages = with pkgs; [
  # Add your package here
  neofetch
];
```

### Modifying Shell Configuration

Edit `modules/shell.nix` to change shell settings, aliases, or environment variables:

```nix
programs.zsh = {
  shellAliases = {
    myalias = "my command";
  };
};
```

### Customizing Git Configuration

Edit `modules/git.nix` to change git settings:

```nix
programs.git = {
  userName = "Your Name";
  userEmail = "your.email@example.com";
};
```

### After Making Changes

Rebuild and switch to the new configuration:

```bash
# If you're already using home-manager
home-manager switch --flake ~/Dotfiles#<profile>

# Or the short version (after adding alias)
hms  # Alias for home-manager switch
```

## Useful Commands

Add these aliases to your shell for convenience (already included in shell.nix):

```bash
# Update flake inputs
nix-update          # Updates flake.lock

# Switch to new configuration
nix-switch          # Rebuilds and activates configuration

# Clean old generations
nix-clean           # Removes old home-manager generations

# Search for packages
nix-search <query>  # Search nixpkgs

# Install package temporarily
nix-shell -p <package>  # Temporary environment with package

# List installed packages
nix-list            # Lists all packages in profile
```

## Managing Configurations

### Viewing Available Configurations

```bash
nix flake show ~/Dotfiles
```

### Switching Between Configurations

```bash
home-manager switch --flake ~/Dotfiles#<configuration>
```

### Rolling Back

If something breaks, you can easily roll back:

```bash
home-manager generations        # List all generations
home-manager switch --switch-generation <number>
```

## Environment-Specific Features

### Arch Linux (`arch.nix`)
- Pacman integration for system packages
- AUR-like experience with Nix flakes
- Includes informant and pacman configs

### Debian/Ubuntu (`debian.nix`)
- APT integration for system packages
- Debian-specific aliases
- Compatible with Ubuntu and derivatives

### WSL (`wsl.nix`)
- Windows path integration
- X11 forwarding support
- WSLg compatibility
- wslu utilities

### Minimal (`minimal.nix`)
- Essential packages only
- Suitable for containers and servers
- Minimal resource footprint

### Proxmox (`proxmox.nix`)
- Server utilities
- Network monitoring tools
- Headless configuration

### GUI (`gui.nix`)
- Sway (Wayland) configuration
- i3 (X11) configuration
- Terminal emulators (kitty, ghostty, alacritty)
- Fonts and themes
- Desktop applications

## Hybrid Approach

You can use Nix alongside your existing package manager:

- **System packages**: Continue using pacman/apt for system-level packages
- **User packages**: Use Nix for user-level packages and dotfiles
- **Development environments**: Use Nix for project-specific dependencies

Example workflow:
```bash
# Install system packages with pacman/apt
sudo pacman -S linux linux-headers

# Install user packages with Nix
nix profile install nixpkgs#ripgrep nixpkgs#fd

# Or better yet, declare them in packages.nix
```

## Troubleshooting

### Nix commands not found

Make sure Nix is in your PATH:
```bash
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### Home Manager not found

Install home-manager:
```bash
nix run home-manager/master -- switch --flake ~/Dotfiles#<profile>
```

### Configuration errors

Check syntax:
```bash
nix flake check ~/Dotfiles
```

### Conflicting files

Home Manager will warn about conflicting files. Backup and remove them:
```bash
mv ~/.zshrc ~/.zshrc.backup
```

## Migration from Old Setup

### Preserving Existing Configurations

The Nix setup symlinks to your existing configuration files where possible:

- `.config/nvim/` - Your existing Neovim config
- `.config/sway/` - Your existing Sway config
- `.config/i3/` - Your existing i3 config
- `.config/starship.toml` - Your existing Starship config
- And many more...

### Gradual Migration

You can migrate gradually:

1. Start with a minimal profile
2. Add configurations incrementally
3. Test each change
4. Keep old setup as backup

### Backing Out

To return to the old setup:

1. Uninstall Home Manager:
   ```bash
   home-manager uninstall
   ```

2. Restore from backups:
   ```bash
   mv ~/.zshrc.backup ~/.zshrc
   ```

## Advanced Usage

### Custom Configuration Profiles

Create your own profile by adding to `flake.nix`:

```nix
homeConfigurations = {
  "myprofile" = mkHomeConfiguration {
    username = builtins.getEnv "USER";
    homeDirectory = builtins.getEnv "HOME";
    extraModules = [
      ./modules/environments/arch.nix
      ./modules/environments/gui.nix
      # Add your custom modules
    ];
  };
};
```

### Per-Machine Customization

Create a `.zshrc.local` file for machine-specific settings:

```bash
# This file is sourced automatically and not managed by Nix
# Put machine-specific settings here
export CUSTOM_VAR="value"
```

### Using Nix Shells for Development

Create a `shell.nix` or use flakes for project environments:

```bash
# Enter development shell
nix develop

# Or create a shell.nix
nix-shell
```

## Further Reading

- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [NixOS Wiki](https://nixos.wiki/)

## Getting Help

- GitHub Issues: https://github.com/Unintendedsideeffects/Dotfiles/issues
- Nix Discourse: https://discourse.nixos.org/
- Home Manager Issues: https://github.com/nix-community/home-manager/issues

---

**Note**: This migration preserves your existing dotfiles while adding Nix for package and configuration management. You can continue to use your existing shell scripts and configurations alongside Nix.
