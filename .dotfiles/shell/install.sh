#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f "$HOME/.zshrc" ]]; then
  printf '%s\n' '[[ -f "$HOME/.dotfiles/shell/zshrc.base" ]] && source "$HOME/.dotfiles/shell/zshrc.base"' > "$HOME/.zshrc"
fi
mkdir -p "$HOME/.zshrc.d"
echo "Shell install complete."