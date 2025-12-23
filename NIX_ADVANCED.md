# Advanced Nix Configuration Guide

This document provides detailed information about the advanced features and configurations available in the Nix-based dotfiles setup.

## Complete Module Reference

### Core Modules

#### **packages.nix** - Package Management
Declares all packages with conditional loading based on environment:

```nix
dotfiles = {
  enableGui = false;          # Enable GUI packages
  enableDevelopment = true;    # Enable dev tools
  enableMinimal = false;       # Minimal package set
};
```

**Package Categories:**
- **Essential** (always installed): Shell, editor, network tools, git
- **Modern CLI Tools**: ripgrep, fd, bat, eza, fzf, zoxide, starship, atuin
- **Development**: gcc, make, python, go, rust, node.js, language servers
- **GUI**: Sway, i3, terminals, fonts, desktop apps

#### **shell.nix** - Shell Configuration
Comprehensive zsh/bash setup with modern tools:

- **History**: 10,000 lines, deduplication, shared across sessions
- **Integrations**: starship, zoxide, fzf, atuin, direnv
- **Aliases**: Modern CLI replacements, git shortcuts, system commands
- **Environment**: Dynamic editor selection, locale setup, XDG directories

#### **git.nix** - Git Configuration
Complete git setup with modern tools:

- **Delta**: Better diff viewer with syntax highlighting
- **Lazygit**: Terminal UI for git operations
- **GitHub CLI**: `gh` for GitHub interactions
- **Aliases**: Comprehensive git shortcuts
- **LFS**: Large file support enabled

#### **scripts.nix** - Dotfiles Scripts
Exposes all scripts from `.dotfiles/bin/` in PATH:

- **Bootstrap scripts**: setup, installation, validation
- **GUI utilities**: rofi integration, wallpaper management, power menu
- **Window manager**: i3/sway workspace management
- **System tools**: updates, monitors, networking

### Program Modules

#### **Terminal Emulators** (`terminal.nix`)
- **Kitty**: GPU-accelerated, modern terminal
- **Alacritty**: Fast, lightweight alternative
- **Ghostty**: Modern terminal with good font rendering

All configured with:
- JetBrainsMono Nerd Font
- 10,000 line scrollback
- Catppuccin Mocha theme
- Copy/paste integration

#### **Terminal Multiplexers**

**Tmux** (`tmux.nix`):
- Vi mode keybindings
- Mouse support
- Plugins: sensible, yank, resurrect, continuum, vim-navigator
- Catppuccin theme
- True color support
- Automatic session restoration

**Zellij** (`zellij.nix`):
- Modern tmux alternative
- Built-in layouts and plugins
- Wayland clipboard integration
- Custom theme support (Flexoki)

#### **Text Editor** (`neovim.nix`)
Neovim with comprehensive LSP and formatter support:

**Language Servers:**
- Nix (nil)
- Lua, TypeScript, Python, Bash, Rust, Go
- HTML/CSS/JSON/ESLint

**Formatters:**
- nixpkgs-fmt, stylua, prettier, black, isort, shfmt, rustfmt, gofumpt

**Tools:**
- tree-sitter for syntax highlighting
- Clipboard support (xclip, wl-clipboard)

**Note:** Uses existing nvim config via symlink for flexibility

#### **File Managers**

**Yazi** (`yazi.nix`):
- Modern, fast file manager
- Vi-like keybindings
- Image previews
- Shell integration (cd on exit)

**Ranger** (`ranger.nix`):
- Classic terminal file manager
- Extensive customization
- Custom scope.sh for previews

#### **System Monitor** (`btop.nix`)
Modern system resource monitor:
- CPU, memory, disk, network monitoring
- Process management
- Vim keybindings
- Braille graph symbols
- Rounded corners
- Battery monitoring

### Window Manager Modules

#### **i3** (`i3.nix`)
X11 tiling window manager:
- Uses existing custom config
- Includes i3-gaps, i3status, i3lock, i3blocks
- Autotiling support
- Layout manager integration

**Keybindings** (from existing config):
- Mod4 (Super) as modifier
- Ghostty as default terminal
- Rofi for application launching
- Flameshot for screenshots
- Focus follows mouse disabled

#### **Sway** (`sway.nix`)
Wayland compositor (i3-compatible):
- Systemd integration
- XWayland support
- Custom config via symlink
- Comprehensive Wayland tooling

**Included Tools:**
- wl-clipboard, wl-mirror, wlr-randr
- swaybg, swaylock, swayidle
- grim, slurp (screenshots)
- wf-recorder (screen recording)
- wtype, ydotool (input automation)

#### **Waybar** (`waybar.nix`)
Status bar for Wayland:
- Workspaces, window title
- System stats (CPU, memory, temperature)
- Battery status
- Network info
- PulseAudio volume
- Clock and tray
- Catppuccin-inspired theme

### Desktop Utilities

#### **Rofi** (`rofi.nix`)
Application launcher and more:
- Wayland support (rofi-wayland)
- Custom theme from .config/rofi
- Additional plugins: rofi-calc, rofi-emoji, rofi-power-menu
- Fuzzy matching
- Icon support

#### **Dunst** (`dunst.nix`)
Notification daemon:
- Mouse follow mode
- 350x10 geometry, top-right placement
- 5% transparency
- Rounded corners (10px)
- Custom colors (dark theme)
- DMenu integration with rofi
- Click actions (close, open, do action)

**Urgency Levels:**
- Low/Normal: Dark background, 10s timeout
- Critical: Purple background, no timeout

#### **Picom** (`picom.nix`)
X11 compositor:
- GLX backend for performance
- Rounded corners (8px)
- Subtle shadows (15% opacity)
- Dual kawase blur (strength 5)
- Fade animations
- 90% frame opacity
- Window type specific settings

## Environment-Specific Features

### **Arch Linux** (`environments/arch.nix`)
```nix
# Pacman/AUR integration
update = "sudo pacman -Syu && nix flake update";
search = "pacman -Ss";
aur = "yay -S";  # Note: Install yay separately

# Nix commands for user packages
nix-search = "nix search nixpkgs";
nix-install = "nix profile install nixpkgs#";
```

**Arch-specific Configs:**
- Informant (Arch news reader)
- Pacman configuration
- YAY configuration

### **Debian/Ubuntu** (`environments/debian.nix`)
```nix
# APT integration
update = "sudo apt update && sudo apt upgrade -y && nix flake update";
install = "sudo apt install";
autoremove = "sudo apt autoremove -y";
```

### **WSL** (`environments/wsl.nix`)
Windows Subsystem for Linux integration:

```nix
# Windows path support
export WINDOWS_HOME="/mnt/c/Users/$USER"

# X11 forwarding (WSL2)
export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0

# WSLg support (built-in GUI)
if [[ -n "$WAYLAND_DISPLAY" ]]; then
  export DISPLAY=:0
fi
```

**WSL Tools:**
- wslu utilities
- wslview for opening URLs
- Windows clipboard integration

### **Minimal** (`environments/minimal.nix`)
Headless server configuration:
- Essential packages only
- No GUI components
- Minimal resource footprint
- Suitable for containers, VMs, servers

### **Proxmox** (`environments/proxmox.nix`)
Server management tools:
- htop, iotop, iftop, ncdu
- tcpdump, nmap
- Server-specific aliases
- Conservative package set

### **GUI** (`environments/gui.nix`)
Desktop environment components:
- Window managers (Sway, i3)
- Status bars (Waybar)
- Launchers and notifications
- Terminal emulators
- Fonts and themes
- GUI autostart on TTY1

## Advanced Usage

### Custom Profiles

Create your own profile in `flake.nix`:

```nix
homeConfigurations = {
  "myprofile" = mkHomeConfiguration {
    username = builtins.getEnv "USER";
    homeDirectory = builtins.getEnv "HOME";
    extraModules = [
      ./modules/environments/arch.nix
      ./modules/environments/gui.nix
      {
        # Inline custom config
        dotfiles.enableGui = true;
        dotfiles.enableDevelopment = true;

        programs.git = {
          userName = "My Name";
          userEmail = "my@email.com";
        };
      }
    ];
  };
};
```

### Per-Machine Customization

**Method 1: Local override file**
Create `~/.config/home-manager/local.nix`:

```nix
{ config, pkgs, ... }:

{
  programs.git = {
    userName = "Work Name";
    userEmail = "work@company.com";
  };

  home.packages = with pkgs; [
    # Machine-specific packages
    docker
    kubectl
  ];
}
```

Import in your profile:
```nix
extraModules = [
  ./modules/environments/arch.nix
  ~/.config/home-manager/local.nix  # Machine-specific
];
```

**Method 2: Shell rc local file**
Create `~/.zshrc.local`:

```bash
# Machine-specific settings not managed by Nix
export CUSTOM_VAR="value"
alias work="cd ~/work/project"

# Add machine-specific PATH entries
export PATH="$HOME/custom/bin:$PATH"
```

This file is automatically sourced by the shell configuration.

### Development Environments

#### Project-Specific Nix Shell

Create `shell.nix` in your project:

```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    python311
    python311Packages.requests
    nodejs
    postgresql
  ];

  shellHook = ''
    echo "Entering development environment"
    export DATABASE_URL="postgresql://localhost/mydb"
  '';
}
```

Enter with `nix-shell`.

#### Using Flakes for Projects

Create `flake.nix` in your project:

```nix
{
  description = "My project development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            python311
            poetry
            black
            mypy
          ];
        };
      }
    );
}
```

Enter with `nix develop`.

#### Direnv Integration

Create `.envrc` in your project:

```bash
use flake
# or
use nix
```

Run `direnv allow` once. Now the environment activates automatically when you cd into the directory!

### Theme Management

Create a centralized theme module in `modules/theme.nix`:

```nix
{ config, pkgs, lib, ... }:

{
  options = {
    theme = {
      colorScheme = lib.mkOption {
        type = lib.types.enum [ "dark" "light" ];
        default = "dark";
      };
    };
  };

  config = {
    # Apply theme to all programs
    programs.kitty.theme =
      if config.theme.colorScheme == "dark"
      then "Catppuccin-Mocha"
      else "Catppuccin-Latte";

    services.dunst.settings.global = {
      background =
        if config.theme.colorScheme == "dark"
        then "#282a2e"
        else "#eff1f5";
    };

    # ... more programs
  };
}
```

### Managing Secrets

**Option 1: sops-nix**
```nix
inputs.sops-nix.url = "github:Mic92/sops-nix";

# In your config
imports = [ inputs.sops-nix.homeManagerModules.sops ];

sops = {
  age.keyFile = "/home/user/.config/sops/age/keys.txt";
  defaultSopsFile = ./secrets.yaml;

  secrets.github_token = {
    path = "${config.home.homeDirectory}/.github_token";
  };
};
```

**Option 2: Pass integration**
```nix
programs.password-store = {
  enable = true;
  package = pkgs.pass;
  settings = {
    PASSWORD_STORE_DIR = "${config.home.homeDirectory}/.password-store";
  };
};

# Use in scripts
github_token=$(pass show github/token)
```

### Systemd User Services

Create custom user services in `modules/services.nix`:

```nix
systemd.user.services = {
  backup = {
    Unit = {
      Description = "Backup home directory";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.rsync}/bin/rsync -av ${config.home.homeDirectory} /backup/";
    };
  };
};

systemd.user.timers = {
  backup = {
    Unit = {
      Description = "Daily backup timer";
    };
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
};
```

### Overlay for Custom Packages

Add overlays in `flake.nix`:

```nix
overlays = [
  (final: prev: {
    myCustomPackage = prev.stdenv.mkDerivation {
      pname = "my-package";
      version = "1.0";
      src = ./my-package;
      installPhase = ''
        mkdir -p $out/bin
        cp my-binary $out/bin/
      '';
    };
  })
];
```

### Optimizations

**Automatic Garbage Collection:**
```nix
# In NixOS configuration
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};

# In Home Manager
systemd.user.timers.nix-gc = {
  Unit.Description = "Nix garbage collection";
  Timer = {
    OnCalendar = "weekly";
    Persistent = true;
  };
  Install.WantedBy = [ "timers.target" ];
};
```

**Store Optimization:**
```bash
# Optimize store (deduplicate)
nix-store --optimise

# Verify store
nix-store --verify --check-contents
```

**Binary Cache:**
```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
  ];
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
};
```

## Troubleshooting Advanced Issues

### Home Manager Build Failures

**Issue**: Collision between packages
```
error: collision between `/nix/store/xxx-foo-1.0/bin/bar' and `/nix/store/yyy-foo-2.0/bin/bar'
```

**Solution**: Use `lib.hiPrio` or `lib.lowPrio`:
```nix
home.packages = [
  (lib.hiPrio pkgs.package1)  # Higher priority
  pkgs.package2
];
```

### Symlink Conflicts

**Issue**: Home Manager can't create symlinks
```
error: Existing file '/home/user/.config/foo' is in the way
```

**Solution**: Backup and remove:
```bash
mv ~/.config/foo ~/.config/foo.backup
home-manager switch
```

### Performance Issues

**Large number of packages slow to build:**

1. Use `nixpkgs-fmt` to organize imports
2. Split packages into categories
3. Use `lib.optionals` for conditional packages
4. Enable binary cache

**Slow shell startup:**

1. Profile zsh: `zsh -xv`
2. Disable unnecessary integrations
3. Use lazy loading for heavy tools

### Module Conflicts

**Issue**: Multiple modules trying to set the same option

Use `lib.mkForce`, `lib.mkDefault`, or `lib.mkOverride`:

```nix
programs.git.userName = lib.mkForce "Specific Name";  # Override everything
programs.git.userEmail = lib.mkDefault "default@email.com";  # Use if not set
```

## Resources

- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Home Manager Options Search](https://mipmip.github.io/home-manager-option-search/)
- [Nix Package Search](https://search.nixos.org/packages)
- [NixOS Wiki](https://nixos.wiki/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [awesome-nix](https://github.com/nix-community/awesome-nix)

## Getting Help

- **IRC**: #home-manager on libera.chat
- **Matrix**: #home-manager:nixos.org
- **Discourse**: https://discourse.nixos.org/
- **GitHub**: https://github.com/nix-community/home-manager/issues
