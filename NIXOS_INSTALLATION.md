# Full NixOS Installation Guide

This guide covers installing a complete NixOS system using this dotfiles repository.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Fresh NixOS Installation](#fresh-nixos-installation)
- [Migrating from Existing System](#migrating-from-existing-system)
- [Configuration Options](#configuration-options)
- [Post-Installation](#post-installation)
- [Troubleshooting](#troubleshooting)

## Overview

This repository now provides **full NixOS system configurations** in addition to Home Manager-only setups. The `nixos-full` branch contains:

- Complete NixOS system configuration
- Modular configuration for boot, networking, desktop, services
- Hardware configuration templates
- Multiple pre-configured system profiles (desktop, laptop, server, WSL)
- Full Home Manager integration

## Prerequisites

### For Fresh Installation

1. Download the NixOS ISO from [nixos.org/download](https://nixos.org/download)
2. Create a bootable USB drive
3. Boot into the NixOS installer

### For Migration

- Existing NixOS installation (version 23.05 or later recommended)
- Git installed
- Flakes enabled in your Nix configuration

## Fresh NixOS Installation

### Step 1: Boot and Partition

Boot into the NixOS installer and partition your disk:

```bash
# Example: UEFI system with GPT partitioning
# WARNING: This will erase all data on /dev/sda
sudo parted /dev/sda -- mklabel gpt
sudo parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
sudo parted /dev/sda -- set 1 esp on
sudo parted /dev/sda -- mkpart primary 512MiB 100%

# Format partitions
sudo mkfs.fat -F 32 -n boot /dev/sda1
sudo mkfs.ext4 -L nixos /dev/sda2

# Mount partitions
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot
```

For encrypted setups:
```bash
# Create encrypted partition
sudo cryptsetup luksFormat /dev/sda2
sudo cryptsetup open /dev/sda2 crypted
sudo mkfs.ext4 -L nixos /dev/mapper/crypted

# Mount encrypted partition
sudo mount /dev/mapper/crypted /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/sda1 /mnt/boot
```

### Step 2: Generate Hardware Configuration

```bash
sudo nixos-generate-config --root /mnt
```

This creates:
- `/mnt/etc/nixos/configuration.nix`
- `/mnt/etc/nixos/hardware-configuration.nix`

### Step 3: Clone Dotfiles Repository

```bash
# Install git in the installer environment
nix-shell -p git

# Clone the repository
cd /mnt/etc
sudo git clone --branch nixos-full https://github.com/Unintendedsideeffects/Dotfiles.git nixos

# Backup the generated hardware configuration
sudo cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hardware-configuration.nix
```

### Step 4: Copy Hardware Configuration

```bash
# Move the generated hardware config to the right place
sudo mv /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/nixos/
```

### Step 5: Customize Configuration

Edit `/mnt/etc/nixos/configuration.nix` and `/mnt/etc/nixos/nixos/modules/users.nix`:

```nix
# In nixos/modules/users.nix
nixos-dotfiles.users = {
  mainUser = "your-username";  # Change from "malcolm"
  mainUserFullName = "Your Full Name";
};

# In nixos/configuration.nix, set hostname
nixos-dotfiles.networking.hostName = "your-hostname";
```

Choose your system profile by selecting the appropriate flake output:
- `nixos-desktop` - Full desktop with i3/Sway
- `nixos-laptop` - Desktop + power management
- `nixos-server` - Headless server
- `nixos-wsl` - Windows Subsystem for Linux

### Step 6: Install NixOS

```bash
# Install using the flake
sudo nixos-install --flake /mnt/etc/nixos#nixos-desktop

# Or for laptop
sudo nixos-install --flake /mnt/etc/nixos#nixos-laptop

# Set root password when prompted
# Create user password
sudo nixos-enter --root /mnt
passwd your-username
exit
```

### Step 7: Reboot

```bash
reboot
```

## Migrating from Existing System

If you already have NixOS installed:

### Step 1: Enable Flakes

Add to `/etc/nixos/configuration.nix`:

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

Rebuild:
```bash
sudo nixos-rebuild switch
```

### Step 2: Clone Repository

```bash
sudo git clone --branch nixos-full https://github.com/Unintendedsideeffects/Dotfiles.git /etc/nixos-dotfiles
```

### Step 3: Backup Current Configuration

```bash
sudo cp -r /etc/nixos /etc/nixos.backup
```

### Step 4: Copy Hardware Configuration

```bash
sudo cp /etc/nixos/hardware-configuration.nix /etc/nixos-dotfiles/nixos/
```

### Step 5: Link Configuration

```bash
sudo rm /etc/nixos/configuration.nix
sudo ln -s /etc/nixos-dotfiles/flake.nix /etc/nixos/flake.nix
```

### Step 6: Customize and Rebuild

Edit the configuration as needed, then:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos-desktop
```

## Configuration Options

### Customizing Your System

All major features are controlled via options in the flake. Edit `flake.nix` or create an override:

```nix
# In flake.nix, modify the nixosConfigurations
nixos-dotfiles = {
  boot = {
    enableSystemdBoot = true;  # or false for GRUB
    enableGrub = false;
  };

  networking = {
    hostName = "my-nixos";
    enableNetworkManager = true;
    enableIwd = false;  # Use iwd instead of wpa_supplicant
    enableBluetooth = true;
  };

  desktop = {
    enable = true;  # false for servers
    enableX11 = true;
    enableWayland = true;
    windowManager = "both";  # "i3", "sway", "both", or "none"
    displayManager = "lightdm";  # "gdm", "sddm", or "none"
  };

  services = {
    enableAudio = true;
    enablePrinting = true;
    enableDocker = false;
    enableVirtualization = false;
  };

  users = {
    mainUser = "malcolm";
    mainUserFullName = "Malcolm";
    extraGroups = [ "networkmanager" "wheel" "audio" "video" ];
  };
};
```

### Available Profiles

The flake provides several pre-configured profiles:

#### `nixos-desktop`
Full desktop environment with:
- i3 and Sway window managers
- LightDM display manager
- Audio (PipeWire)
- Bluetooth
- Printing
- All desktop applications

#### `nixos-laptop`
Desktop configuration plus:
- TLP power management
- Better battery life optimizations
- Laptop-specific kernel modules

#### `nixos-server`
Minimal headless server:
- No desktop environment
- SSH enabled
- Essential server tools
- Minimal resource usage

#### `nixos-wsl`
Windows Subsystem for Linux:
- WSL integration
- No desktop (use WSLg if needed)
- Windows path integration

### Module Structure

```
nixos/
├── configuration.nix          # Main system configuration
├── hardware-configuration.nix # Generated hardware config
├── modules/
│   ├── boot.nix              # Bootloader configuration
│   ├── networking.nix        # Network and Bluetooth
│   ├── desktop.nix           # Desktop environment
│   ├── services.nix          # System services
│   └── users.nix             # User management
└── packages/
    └── dotfiles-scripts.nix  # Custom scripts package
```

## Post-Installation

### 1. Update Flake Inputs

```bash
cd /etc/nixos
sudo nix flake update
sudo nixos-rebuild switch --flake .#nixos-desktop
```

### 2. Install Home Manager Packages

Your user-specific packages are managed by Home Manager (integrated automatically):

```bash
# Home Manager is already active via NixOS module
# Your config is in ~/.config/home-manager or defined in the flake
```

### 3. Configure Git

Set up your git credentials:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

Or edit `modules/git.nix` and rebuild.

### 4. Set Up SSH Keys

```bash
ssh-keygen -t ed25519 -C "your.email@example.com"
```

### 5. Enable Optional Services

Edit `/etc/nixos/configuration.nix` or your flake to enable:

```nix
# Enable Docker
nixos-dotfiles.services.enableDocker = true;

# Enable virtualization
nixos-dotfiles.services.enableVirtualization = true;

# Enable TLP (laptops)
services.tlp.enable = true;
```

Then rebuild:
```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos-desktop
```

## Troubleshooting

### Build Failures

**Check syntax:**
```bash
nix flake check /etc/nixos
```

**Verbose build:**
```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos-desktop --show-trace
```

### Hardware Not Detected

Regenerate hardware configuration:
```bash
sudo nixos-generate-config
sudo cp /etc/nixos/hardware-configuration.nix /etc/nixos-dotfiles/nixos/
```

### Display Manager Won't Start

Check logs:
```bash
sudo journalctl -u display-manager -b
```

Try switching to console:
```bash
# Ctrl+Alt+F2
sudo nixos-rebuild switch --flake /etc/nixos#nixos-desktop
```

### WiFi Not Working

Check if firmware is loaded:
```bash
sudo dmesg | grep firmware
```

Add firmware packages in hardware-configuration.nix:
```nix
hardware.enableRedistributableFirmware = true;
```

### Audio Not Working

Check PipeWire status:
```bash
systemctl --user status pipewire
systemctl --user status pipewire-pulse
```

Restart audio:
```bash
systemctl --user restart pipewire pipewire-pulse
```

### Rollback to Previous Generation

```bash
# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback
sudo nixos-rebuild switch --rollback

# Or select specific generation
sudo /nix/var/nix/profiles/system-42-link/bin/switch-to-configuration switch
```

## Advanced Topics

### Custom Module Creation

Create a custom module in `nixos/modules/custom.nix`:

```nix
{ config, lib, pkgs, ... }:

{
  options = {
    custom.myFeature.enable = lib.mkEnableOption "My custom feature";
  };

  config = lib.mkIf config.custom.myFeature.enable {
    # Your configuration here
  };
}
```

Import it in `configuration.nix`:
```nix
imports = [
  ./modules/custom.nix
];
```

### Multiple Machine Configuration

Create machine-specific configs:

```nix
# flake.nix
nixosConfigurations = {
  "machine1" = mkNixosConfiguration {
    hostname = "machine1";
    modules = [ ./machines/machine1.nix ];
  };

  "machine2" = mkNixosConfiguration {
    hostname = "machine2";
    modules = [ ./machines/machine2.nix ];
  };
};
```

### Secrets Management

Use `agenix` or `sops-nix` for secrets:

```nix
# Add to flake inputs
inputs.agenix.url = "github:ryantm/agenix";

# In configuration
imports = [ agenix.nixosModules.default ];
age.secrets.my-secret.file = ./secrets/my-secret.age;
```

## Further Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [NixOS Discourse](https://discourse.nixos.org/)
- [NixOS Wiki](https://nixos.wiki/)

## Support

- GitHub Issues: https://github.com/Unintendedsideeffects/Dotfiles/issues
- NixOS Discourse: https://discourse.nixos.org/

---

**Happy NixOS hacking! 🚀**
