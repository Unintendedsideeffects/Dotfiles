# Malcolm's Dotfiles

Cross-platform dotfiles for Linux development environments. Works on Arch, Debian/Ubuntu, Rocky Linux/RHEL, Proxmox, and WSL2.

## Features

- **Universal Support**: Arch, Debian/Ubuntu, Rocky Linux (RHEL), Proxmox, and WSL2.
- **Smart Detection**: Automatically configures for your specific environment.
- **Interactive Bootstrap**: TUI menu to select components (Packages, VPN, Git, etc.).
- **Modern Toolchain**: Neovim, Ghostty, Yazi, Zellij, Atuin, Starship.
- **Headless Power**: Specialized setups for headless GUIs (Xvfb/VNC) and remote Obsidian.
- **WSL Ready**: Deep integration for WSL2 (systemd, Windows paths, `wsl.conf` fixes).

## Quick Setup

```bash
curl -fsSL https://raw.githubusercontent.com/Unintendedsideeffects/Dotfiles/master/.SHA256SUMS -o .SHA256SUMS && \
curl -fsSL https://raw.githubusercontent.com/Unintendedsideeffects/Dotfiles/master/.dotfiles/bin/quick-install.sh -o quick-install.sh && \
grep 'quick-install.sh' .SHA256SUMS | sha256sum -c - && \
bash quick-install.sh && rm .SHA256SUMS quick-install.sh
```

This will:
- Clone the repository to `~/.cfg` (bare repo pattern).
- Back up conflicting files to `~/.local/backups/dotfiles/`.
- Install core shell configuration (Zsh, Starship).

## Managing Dotfiles

This repo uses the "bare git repository" technique.

```bash
config status           # Check for changes
config add .zshrc       # Add a file
config commit -m "..."  # Commit
config push             # Push changes
```

## What You Get

**Core Environment:**
- **Shell**: Zsh configured with `antidote`, `starship` prompt, and `atuin` shell history.
- **Navigation**: `zoxide` (smart cd), `yazi` (file manager), `ranger` (classic FM).
- **Editors**: Neovim (Lua config), Cursor (settings/keybindings).
- **Terminal Multiplexers**: `zellij` and `tmux` (flexoki themed).
- **Terminals**: `ghostty` config, plus support for others.

**CLI Tools:**
- Modern replacements: `ripgrep` (grep), `fd` (find), `bat` (cat), `eza` (ls), `fzf`.
- Git: Configured with `delta` for diffs and `rerere` enabled.

**GUI (Linux):**
- Tiling WMs: `i3` and `sway` configurations.
- Utilities: `rofi` (launcher), `dunst` (notifications), `picom` (compositor).

**Environment-Specifics:**
- **Arch**: Pacman/Yay, AUR support.
- **Debian/Ubuntu**: Apt, build-essential.
- **Rocky/RHEL**: Dnf/Yum support.
- **WSL**: `wslu`, systemd integration, Windows path management.

## Interactive Bootstrap

The `bootstrap.sh` script provides a TUI to manage your setup:

1.  **Install Packages**: Auto-detects distro and installs curated toolsets.
2.  **AUR Setup**: Installs `yay` (Arch only).
3.  **Locale Setup**: Configures UTF-8 locale (essential for Starship/Glyphs).
4.  **Git Config**: Sets global user/email and credentials.
5.  **Claude Code**: Installs statusline integration for Claude CLI.
6.  **Tailscale**: Installs and configures Tailscale VPN.
7.  **WSL Setup**: Fixes `/etc/wsl.conf` and enables systemd (WSL only).
8.  **GUI Autologin**: Configures auto-start for X11/Wayland.
9.  **Headless GUI**: Sets up Xvfb/Openbox/VNC for remote GUI apps (Arch).
10. **Headless Obsidian**: Specialized container-like setup for Obsidian on servers.
11. **Validate**: Checks environment health and missing tools.




## Customization

- **Local Config**: Create `~/.zshrc.local` for machine-specific shell overrides.
- **Git**: Use `~/.gitconfig.local` for private git settings (auto-created by bootstrap).
- **Packages**: Add packages to `.dotfiles/pkglists/*.txt`.


