# Shell Configuration

This directory contains a modular, environment-aware shell configuration system that automatically adapts to different environments while maintaining consistency across machines.

---

## ⚡ Dotfiles Management with a Bare Git Repo

This setup is designed to be used with a [bare git repo](https://www.atlassian.com/git/tutorials/dotfiles) and a `config` alias for seamless, symlink-free management.

### Initial Setup

```bash
git clone --bare git@github.com:youruser/dotfiles.git $HOME/.cfg
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
config checkout
config config --local status.showUntrackedFiles no
```

- The tracked `.zshrc` lives at `$HOME/.zshrc` and is the entrypoint.
- All modular configs live in `~/Dotfiles/shell/`.
- Never track `~/.zshrc.local` (per-host overrides).

### Best Practices
- Use `config status` to check for drift.
- To add a new machine, repeat the above steps.
- To update, use `config add`, `config commit`, `config push` as with any git repo.

---

## Structure

```
shell/
├── .zshrc.new          # Minimal bootstrapper (symlinked to ~/.zshrc)
├── zshrc.base          # Common configuration (symlinked to ~/.zshrc.base)
├── zshrc.d/            # Environment-specific configurations
│   ├── arch.zsh        # Arch Linux specific
│   ├── rocky.zsh       # Rocky Linux (VMware) specific
│   ├── crostini.zsh    # Crostini (Pixelbook) specific
│   ├── wsl.zsh         # WSL specific
│   └── enterprise.zsh  # Work/enterprise specific
├── install.sh          # Installation script
└── README.md           # This file
```

## Design Philosophy

**Composable and Declarative**: The main `.zshrc` is minimal and delegates to environment-specific fragments. This prevents config sprawl while allowing each environment to diverge just enough.

**Environment Detection**: Automatically detects the current environment and loads appropriate configurations:
- `IS_ARCH` - Arch Linux
- `IS_ROCKY` - Rocky Linux
- `IS_WSL` - Windows Subsystem for Linux
- `IS_CROSTINI` - Crostini (Pixelbook)
- `IS_ENTERPRISE` - Work environment (when symlinked)

## Installation

1. Run the installation script:
   ```bash
   cd shell
   ./install.sh
   ```

2. Restart your shell or source the configuration:
   ```bash
   source ~/.zshrc
   ```

3. Verify environment detection:
   ```bash
   echo "Arch: $IS_ARCH, Rocky: $IS_ROCKY, WSL: $IS_WSL, Crostini: $IS_CROSTINI"
   ```

## Usage

### Local Overrides

Add machine-specific configurations to `~/.zshrc.local` (not versioned in git):

```bash
# ~/.zshrc.local
export CUSTOM_VAR="value"
alias myalias="mycommand"
```

### Enterprise Configuration

To enable work-specific configurations:

```bash
ln -s ~/.dotfiles/shell/zshrc.d/enterprise.zsh ~/.zshrc.d/
```

### Adding New Environments

1. Create a new configuration file in `zshrc.d/`
2. Add environment detection logic to `zshrc.base`
3. Add loading logic to `.zshrc.new`

## Environment-Specific Features

### Arch Linux
- Package management aliases (`update`, `install`, `remove`, `search`, `aur`)
- Pacman configuration

### Rocky Linux (VMware)
- DNF package management aliases
- VMware-specific environment variables
- System management aliases

### Crostini (Pixelbook)
- ChromeOS integration
- File system mounting
- Display and audio configuration

### WSL
- Windows integration aliases
- File system mounting
- Display forwarding

### Enterprise
- Corporate VPN and SSH functions
- Java and Maven configuration
- Corporate Git settings

## Migration from Old Configuration

The installation script automatically backs up your existing `.zshrc` to `.zshrc.backup`. To restore:

```bash
mv ~/.zshrc.backup ~/.zshrc
```

## Troubleshooting

1. **Environment not detected**: Check the detection logic in `zshrc.base`
2. **Config not loading**: Verify symlinks with `ls -la ~/.zshrc*`
3. **Conflicts**: Check `~/.zshrc.local` for conflicting configurations 