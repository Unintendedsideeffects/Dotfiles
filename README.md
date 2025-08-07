# Malcolm's Dotfiles

Portable dotfiles for Arch, Debian, and Proxmox. Minimal, fast, and consistent.

## Features

- **Cross-distro**: Arch, Debian, Proxmox (Proxmox treated as Debian with safe defaults)
- **Bare repo**: Manage dotfiles cleanly with a git bare repository
- **Bootstrap**: One command installs curated CLI packages
- **Modular shell**: Minimal zsh base + per-distro modules

## Quick start

```bash
git clone --bare https://github.com/Unintendedsideeffects/Dotfiles.git "$HOME/.cfg"
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
config checkout 2>&1 | grep -E "\s+\." | awk '{print $1}' | xargs -I{} mv {} {}.backup || true
config checkout
source "$HOME/.dotfiles/cli/config.sh"
chmod +x "$HOME/.dotfiles/bin/bootstrap.sh" "$HOME/.dotfiles/shell/install.sh" "$HOME/.dotfiles/bin/validate.sh" 2>/dev/null || true
"$HOME/.dotfiles/shell/install.sh"
"$HOME/.dotfiles/bin/bootstrap.sh"
```

## Directory structure

```
.
└── .dotfiles/
    ├── bin/
    │   ├── bootstrap.sh
    │   └── validate.sh
    ├── cli/
    │   └── config.sh
    ├── shell/
    │   ├── install.sh
    │   ├── zshrc.base
    │   └── zshrc.d/
    │       ├── arch.zsh
    │       ├── debian.zsh
    │       └── proxmox.zsh
    └── pkglists/
        ├── arch-cli.txt
        ├── debian-cli.txt
        └── proxmox-cli.txt
```

## Environment detection

Detected via `/etc/os-release` and Proxmox presence. Proxmox uses the Debian list with a conservative set.

## Packages

Curated minimal lists per distro. Order matters: core tools → CLI → runtimes → toolchain → fonts.

- Arch: pacman installs from `arch-cli.txt`. AUR is not automated.
- Debian: apt installs from `debian-cli.txt`.
- Proxmox: apt installs from `proxmox-cli.txt`.

### Package Manager Configuration

#### Pacman (Arch Linux)
- **Optimized Settings**: 8 parallel downloads, color output, progress bars
- **Build Optimization**: Multi-core compilation, ccache, LTO support
- **Custom Cache**: User-specific package and build cache directories

#### Yay (AUR Helper)
- **Smart Defaults**: Clean after build, show diffs, upgrade menu
- **Performance**: Batch operations, combined upgrades
- **Security**: PGP verification, dependency checking

## Shell

`zshrc.base` sets sane defaults and aliases. Per-distro modules load automatically. `bat` aliases to `batcat` on Debian/Proxmox. `fd` aliases to `fdfind` on Debian/Proxmox.

## Managing dotfiles

Use the `config` alias defined in `./.dotfiles/cli/config.sh` for all git operations.

## Manual steps

1. `./.dotfiles/shell/install.sh`
2. `./.dotfiles/bin/bootstrap.sh`
3. `source .dotfiles/cli/config.sh`

## Validation

`./.dotfiles/bin/validate.sh` prints detected distro and checks for key tools.

## Customization

- **Local Overrides**: Use `~/.zshrc.local` for machine-specific settings
- **Secrets**: Store sensitive data in `secrets/` directory
- **Additional Packages**: Add to appropriate `.dotfiles/pkglists/*.txt` file
- **Environment-Specific**: Modify files in `.dotfiles/shell/zshrc.d/`

## Testing

Verify your setup:
```bash
./.dotfiles/bin/test-dotfiles.sh
```

## Troubleshooting

1. Ensure scripts are executable: `chmod +x .dotfiles/bin/* .dotfiles/shell/*`
2. Confirm the correct package list exists for your distro
3. Use `config status` to inspect changes

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test on your target environments
4. Submit a pull request

This dotfiles system is designed to be a comprehensive, yet flexible foundation for any Linux development environment.