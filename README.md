# Dotfiles

Cross-platform dotfiles for Linux development environments. Works on Arch, Debian/Ubuntu, Rocky Linux/RHEL, Proxmox, and WSL2.

## Quick Setup

```bash
curl -fsSL https://raw.githubusercontent.com/Unintendedsideeffects/Dotfiles/master/.dotfiles/bin/quick-install.sh | bash
```

This clones the repo as a bare git repository to `~/.cfg`, backs up any conflicting files to `~/.local/backups/dotfiles/`, installs shell configuration, and launches the interactive bootstrap menu.

To reinstall over an existing setup:

```bash
curl -fsSL https://raw.githubusercontent.com/Unintendedsideeffects/Dotfiles/master/.dotfiles/bin/quick-install.sh | bash -s -- --reinstall
```

## Managing Dotfiles

Uses the [bare git repository](https://www.atlassian.com/git/tutorials/dotfiles) technique. The `config` alias is set up automatically:

```bash
config status           # Check for changes
config add .zshrc       # Stage a file
config commit -m "..."  # Commit
config push             # Push to remote
```

## What's Included

| Category | Tools |
|----------|-------|
| **Shell** | Zsh, `antidote`, `starship`, `atuin` history |
| **Navigation** | `zoxide`, `yazi`, `ranger` |
| **Editors** | Neovim (Lua config), Cursor |
| **Multiplexers** | `zellij`, `tmux` (flexoki themed) |
| **Terminal** | `ghostty` config |
| **CLI** | `ripgrep`, `fd`, `bat`, `eza`, `fzf`, `delta` |
| **GUI (Linux)** | `i3`, `sway`, `rofi`, `dunst`, `picom` |

**Distro support:** Arch (pacman/yay), Debian/Ubuntu (apt), Rocky/RHEL (dnf), WSL2 (systemd, `wslu`).

## Interactive Bootstrap

Run `~/.dotfiles/bin/bootstrap.sh` to launch the TUI menu. Available options adapt to your platform:

| Option | Description | Availability |
|--------|-------------|--------------|
| Install Packages | Curated toolsets, auto-detects distro + Nerd Fonts, starship, atuin, eza on Debian/Proxmox | All |
| AUR Setup | Installs `yay` | Arch only |
| Locale Setup | UTF-8 locale (needed for Starship/glyphs) | All |
| Git Config | Global user/email and credentials | All |
| Claude Code | Statusline integration for Claude CLI | All |
| Tailscale | Installs and configures Tailscale VPN | All |
| WSL Setup | Fixes `wsl.conf`, enables systemd | WSL only |
| GUI Autologin | Auto-start for X11/Wayland | All |
| Headless GUI | Xvfb/WM/VNC for remote GUI apps | Arch only |
| Headless Obsidian | Xvfb/Openbox/VNC for Obsidian on servers | Arch only |
| Validate | Environment health check | All |

## Headless Obsidian

Uses the official AppImage with a local wrapper and systemd services.

```bash
sudo .dotfiles/bin/install-obsidian-headless.sh \
  -u "$USER" \
  -o 1.12.4 \
  -v "$HOME/Code/Obsidian/ObsidianVault"
```

Installs `~/Applications/Obsidian-<version>.AppImage`, wrapper scripts in `~/.local/bin/`, and systemd services for Xvfb, the window manager, x11vnc, Obsidian, and `ob sync`.

**Post-install:**

1. Open Obsidian over VNC and enable `Settings -> General -> Command line interface`
2. `ob login --email <email>`
3. `ob sync-setup --vault <name-or-id> --path <vault-path> --device-name <name>`
4. `sudo systemctl enable --now obsidian-headless-sync.service`

## Customization

- **Shell**: `~/.zshrc.local` for machine-specific overrides
- **Git**: `~/.gitconfig.local` for private settings (auto-created by bootstrap)
- **Packages**: `.dotfiles/pkglists/*.txt`

## Testing

```bash
# Docker (Arch)
docker build -t dotfiles-test .

# Dev container (Debian)
# Open in VS Code / Codespaces with the .devcontainer config
```
