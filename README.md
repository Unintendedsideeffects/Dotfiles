# Malcolm's Dotfiles

Cross-platform dotfiles for Linux development environments. Works on Arch, Debian/Ubuntu, Proxmox, and WSL2.

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
This will:
- Clone the dotfiles repository
- Back up any conflicting files to `~/.local/backups/dotfiles/` (keeping 5 most recent)
- Install shell configuration
- Skip interactive bootstrap (no TTY available when piped)
- To access the full setup menu, run `~/.dotfiles/bin/bootstrap.sh` after installation

**First-time root setup (creates new user):**
```bash
# Run as root for initial system setup
curl -fsSL https://raw.githubusercontent.com/Unintendedsideeffects/Dotfiles/master/.dotfiles/bin/quick-install.sh | bash
# You'll be prompted to:
#   - Create a new user (optional)
#   - Set up passwordless sudo (optional, with warning)
#   - Install dotfiles for root or the new user
```

**Safer one-liner (pin commit + verify checksum):**
```bash
COMMIT=<commit>
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
SUMS_FILE="$(mktemp "$CACHE_DIR/dotfiles.SHA256SUMS.XXXXXX")"
SCRIPT_FILE="$(mktemp "$CACHE_DIR/dotfiles.quick-install.XXXXXX")"
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/Unintendedsideeffects/Dotfiles/$COMMIT/.SHA256SUMS \
  -o "$SUMS_FILE" &&
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/Unintendedsideeffects/Dotfiles/$COMMIT/.dotfiles/bin/quick-install.sh \
  -o "$SCRIPT_FILE" &&
grep 'quick-install.sh' "$SUMS_FILE" | sha256sum -c - &&
bash "$SCRIPT_FILE"
rm -f "$SUMS_FILE" "$SCRIPT_FILE"
```

**Safer install (review script first):**
```bash
curl -fsSL https://raw.githubusercontent.com/Unintendedsideeffects/Dotfiles/master/.dotfiles/bin/quick-install.sh -o /tmp/quick-install.sh
less /tmp/quick-install.sh
bash /tmp/quick-install.sh
```

**Or manual setup:**
```bash
git clone --bare https://github.com/Unintendedsideeffects/Dotfiles.git "$HOME/.cfg"
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
# Back up conflicting files
cd "$HOME"
backup_dir="$HOME/.local/backups/dotfiles/.dotfiles-backup.$(date +%s)"
mkdir -p "$backup_dir"
config checkout 2>&1 | grep -E "\s+\." | awk '{print $1}' | xargs -I{} bash -c "mkdir -p '$backup_dir/\$(dirname \"{}\")' && mv \"$HOME/{}\" '$backup_dir/{}'" || true
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

## Git Configuration

This dotfiles repository includes git rerere (reuse recorded resolution) configuration to automatically resolve merge conflicts you've resolved before. Learn more: [Git Tools - Rerere](https://git-scm.com/book/en/v2/Git-Tools-Rerere)

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

## Maintainer Notes

When `quick-install.sh` changes, regenerate checksums:
```bash
./.dotfiles/bin/update-sha256sums.sh
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
