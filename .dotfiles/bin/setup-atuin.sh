#!/usr/bin/env bash
set -euo pipefail

if ! command -v atuin >/dev/null 2>&1; then
  echo "Atuin is not installed. Install it from your package list first."
  exit 1
fi

echo "Importing existing shell history into Atuin..."
atuin import auto || true

echo "Atuin setup complete. Default config is local-only (~/.config/atuin/config.toml)."
echo "To enable sync:"
echo "  atuin register   # or: atuin login -u <user> -p <pass> -k <key>"
echo "  atuin config set auto_sync true"
echo "  # and in config: [sync] records = true"


