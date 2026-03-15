#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$HOME/.zshrc" ]]; then
  install -m 0644 "$DOTFILES_ROOT/shell/.zshrc" "$HOME/.zshrc"
fi

echo "Shell install complete."
