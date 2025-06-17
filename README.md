# Dotfiles

A portable, reproducible dotfiles setup that works across WSL, servers, and desktop Linux.

## Directory Structure

```
.
├── bin/          # Executable scripts and CLI tools
├── cli/          # Shell, git, tmux configurations
├── gui/          # X11/Wayland configurations
├── vscode/       # VS Code settings and extensions
├── pkglists/     # Package manifests per distro
└── secrets/      # Sensitive data (gitignored)
```

## Quick Start

1. Clone the repository:
   ```bash
   git clone --bare https://github.com/yourusername/dotfiles.git $HOME/.dotfiles
   ```

2. Define the alias in your current shell:
   ```bash
   alias config='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
   ```

3. Checkout the actual content from the bare repository to your $HOME:
   ```bash
   config checkout
   ```

4. For WSL or headless servers, use sparse checkout:
   ```bash
   config sparse-checkout init --cone
   config sparse-checkout set bin cli
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