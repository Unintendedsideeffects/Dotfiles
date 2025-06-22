# Malcolm's Dotfiles

A comprehensive, portable dotfiles system for Linux environments (WSL, servers, desktop). This repository provides a complete development environment setup with automatic OS detection, package management, and configuration deployment.

## Features

- **Multi-OS Support**: Arch Linux, Rocky Linux/RHEL, with WSL and Crostini detection
- **Bare Repository Setup**: Uses Git bare repository for clean home directory management
- **Automatic Bootstrap**: One-command setup with OS-specific package installation
- **Modular Shell Config**: Environment-aware zsh configuration with platform-specific modules
- **Safe Operations**: Automatic backup of conflicting files during updates
- **Modern CLI Tools**: Pre-configured aliases for modern replacements (exa, bat, ripgrep, etc.)

## Quick Start

```bash
# Set up bare repository
git clone --bare https://github.com/Unintendedsideeffects/Dotfiles.git $HOME/.cfg

# Set up temporary alias for initial checkout
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# Checkout files (backup existing if needed)
config checkout 2>&1 | grep -E "\s+\." | awk '{print $1}' | xargs -I{} mv {} {}.backup
config checkout

# Source the config function from the dotfiles
source $HOME/.dotfiles/cli/config.sh

# Run bootstrap to install packages and configure
./.dotfiles/bin/bootstrap.sh
```

## Directory Structure

```
.
├── .dotfiles/         # Main dotfiles directory
│   ├── bin/           # Utility scripts and tools
│   │   ├── bootstrap.sh  # Main setup script
│   │   └── *.sh       # Various utility scripts
│   ├── cli/           # Shell configurations
│   │   ├── aliases    # Modern CLI tool aliases
│   │   ├── config.sh  # Safe git pull function
│   │   └── common.sh  # Common shell utilities
│   ├── shell/         # Zsh configuration
│   │   ├── install.sh # Shell config installer
│   │   ├── zshrc.base # Base zsh configuration
│   │   └── zshrc.d/   # Environment-specific configs
│   │       ├── arch.zsh     # Arch Linux specific
│   │       ├── rocky.zsh    # Rocky Linux specific
│   │       ├── wsl.zsh      # WSL specific
│   │       ├── crostini.zsh # Chrome OS specific
│   │       └── enterprise.zsh # Enterprise environments
│   └── pkglists/      # Package lists per OS/environment
│       ├── arch-cli.txt     # Arch CLI packages
│       ├── arch-gui.txt     # Arch GUI packages
│       ├── arch-crostini.txt # Crostini-specific packages
│       ├── rocky-cli.txt    # Rocky Linux CLI packages
│       └── rocky-gui.txt    # Rocky Linux GUI packages
├── .config/           # Application configurations
│   ├── pacman/        # Pacman and makepkg configs
│   │   ├── pacman.conf    # Custom pacman settings
│   │   └── makepkg.conf   # Build optimization settings
│   └── yay/           # AUR helper configuration
│       └── config.json    # Yay preferences and settings
├── secrets/           # Sensitive data (gitignored)
└── README.md          # This documentation
```

## Environment Detection

The system automatically detects and configures for:

- **Arch Linux**: Installs AUR helper (yay), uses pacman/yay for packages
- **Rocky Linux/RHEL**: Uses dnf for package management
- **WSL**: Skips GUI packages and X11 configurations
- **Crostini**: Chrome OS Linux container optimizations
- **Enterprise**: Corporate environment configurations

## Package Management

Each environment has curated package lists:

### Arch Linux
- **CLI**: Development tools, modern CLI replacements, fonts
- **GUI**: Desktop environment, applications, themes
- **Crostini**: Chrome OS optimized packages

### Rocky Linux
- **CLI**: Enterprise-friendly development stack
- **GUI**: Desktop applications and utilities

### Package Manager Configuration

#### Pacman (Arch Linux)
- **Optimized Settings**: 8 parallel downloads, color output, progress bars
- **Build Optimization**: Multi-core compilation, ccache, LTO support
- **Custom Cache**: User-specific package and build cache directories

#### Yay (AUR Helper)
- **Smart Defaults**: Clean after build, show diffs, upgrade menu
- **Performance**: Batch operations, combined upgrades
- **Security**: PGP verification, dependency checking

## Shell Configuration

The zsh setup includes:

- **Base Configuration**: Core zsh settings, history, completions
- **Modern Aliases**: exa (ls), bat (cat), ripgrep (grep), and more
- **Environment Modules**: Platform-specific customizations
- **Git Integration**: Enhanced git aliases and prompt
- **Development Tools**: Docker, Kubernetes, Python, Node.js shortcuts

## Configuration Management

### Safe Updates
The `config` function provides safe git operations:
```bash
config pull  # Automatically backs up conflicting files
config add <file>
config commit -m "message"
config push
```

### Sparse Checkout for Minimal Environments
For servers or WSL where you only need CLI tools:
```bash
config sparse-checkout init --cone
config sparse-checkout set .dotfiles/bin .dotfiles/cli .dotfiles/shell .dotfiles/pkglists
```

## Manual Installation Steps

If you prefer manual setup:

1. **Install Shell Configuration:**
   ```bash
   ./.dotfiles/shell/install.sh
   ```

2. **Install Packages:**
   ```bash
   # Arch Linux
   ./.dotfiles/bin/bootstrap.sh
   
   # Or manually:
   yay -S --needed - < .dotfiles/pkglists/arch-cli.txt
   ```

3. **Configure Git:**
   ```bash
   # Set up the config alias
   source .dotfiles/cli/config.sh
   ```

**Note:** On Arch Linux, optimized package manager configurations are automatically applied during bootstrap!

## Package Manager Setup

### Automatic Configuration (Arch Linux)

Package manager optimizations are **automatically applied** when you run the bootstrap script on Arch Linux. The setup includes:

- Backing up existing configurations
- Applying optimized pacman and makepkg settings
- Configuring yay with smart defaults
- Installing ccache for faster builds
- Creating user-specific cache directories

### Manual Configuration (If Needed)

If you need to apply configurations separately or on an existing system:

```bash
# Use the dedicated setup script
./.dotfiles/bin/setup-pacman.sh

# Or apply manually:
sudo cp .config/pacman/pacman.conf /etc/pacman.conf
sudo cp .config/pacman/makepkg.conf /etc/makepkg.conf
mkdir -p ~/.config/yay && cp .config/yay/config.json ~/.config/yay/config.json
```

### What These Configurations Do

- **Pacman**: Enables 8 parallel downloads, color output, and progress indicators
- **Makepkg**: Uses all CPU cores, enables ccache and LTO for faster/smaller builds  
- **Yay**: Configured for safety (diffs, menus) and performance (clean builds)
- **Cache Directories**: Keeps build artifacts in user directory instead of `/tmp`

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

### Common Issues

1. **Permission Denied**: Run `chmod +x .dotfiles/bin/*` to make scripts executable
2. **Missing Packages**: Check if your OS package list exists in `.dotfiles/pkglists/`
3. **Config Conflicts**: Use `config status` to see uncommitted changes

### Getting Help

- Check existing issues and configurations
- Ensure your OS is supported (Arch, Rocky Linux)
- Verify internet connection for package downloads

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test on your target environments
4. Submit a pull request

This dotfiles system is designed to be a comprehensive, yet flexible foundation for any Linux development environment.