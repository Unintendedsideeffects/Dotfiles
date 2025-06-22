# Dotfiles

A portable, reproducible dotfiles setup that works across WSL, servers, and desktop Linux.

## Directory Structure

```
.
├── bin/          # Executable scripts and CLI tools
├── cli/          # Non-XDG shell configurations (.zshrc, .tmux.conf)
├── .config/      # XDG-compliant configurations
│   ├── git/      # Git configuration
│   ├── nvim/     # Neovim configuration
│   ├── htop/     # htop configuration
│   ├── kitty/    # Kitty terminal configuration
│   ├── sway/     # Sway window manager config
│   ├── rofi/     # Rofi launcher configuration
│   └── dunst/    # Dunst notification daemon
├── vscode/       # VS Code settings and extensions
├── pkglists/     # Package manifests per distro
└── secrets/      # Sensitive data (gitignored)
```

## 🚀 Quickstart

1.  **Clone the repository:**

    ```bash
    git clone --bare https://github.com/Unintendedsideeffects/Dotfiles.git $HOME/.cfg
    ```

2.  **Set up the `config` alias:**

    Add this to your `.bashrc` or `.zshrc`:

    ```bash
    alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
    ```

3.  **Checkout the files:**
   ```bash
   config checkout
   ```

4. For WSL or headless servers, use sparse checkout:
   ```bash
   config sparse-checkout init --cone
   config sparse-checkout set bin cli .config/git .config/htop .config/nvim
   ```

5. Install Powerlevel10k (once per host):
   ```bash
   git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
   ```

## Package Installation

### Arch Linux
```bash
# CLI only
while read -r p; do sudo pacman -S --needed "$p"; done < pkglists/arch-cli.txt

# Full desktop
while read -r p; do sudo pacman -S --needed "$p"; done < pkglists/arch-gui.txt
```

### Rocky Linux
```bash
# CLI only
while read -r p; do sudo dnf install -y "$p"; done < pkglists/rocky-cli.txt

# Full desktop
while read -r p; do sudo dnf install -y "$p"; done < pkglists/rocky-gui.txt
```

## Maintenance

- Keep secrets in `secrets/` directory (gitignored)
- Use `config` alias for all git operations
- Run `chmod +x bin/*` after adding new scripts
- Ensure all scripts have proper shebangs

## Development

1. Make changes to the files
2. Use the `config` alias to commit:
   ```bash
   config add <file>
   config commit -m "message"
   config push
   ```

## Testing

Run the test script to verify the setup:
```bash
./bin/test-dotfiles.sh
```