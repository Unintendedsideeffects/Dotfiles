#!/usr/bin/env bash
# Install Claude Code statusline configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v jq >/dev/null 2>&1; then
    echo "WARNING: jq is required for the statusline to render workspace/model info."
    echo "Install it first (e.g., apt-get install jq / pacman -S jq)."
fi

mkdir -p ~/.claude
cp "$SCRIPT_DIR/statusline-command.sh" ~/.claude/
chmod +x ~/.claude/statusline-command.sh

# Merge settings if exists, otherwise copy
if [[ -f ~/.claude/settings.json ]]; then
    echo "~/.claude/settings.json exists - add statusLine config manually:"
    cat "$SCRIPT_DIR/settings.json"
else
    cp "$SCRIPT_DIR/settings.json" ~/.claude/
    echo "Installed settings.json"
fi

echo "Claude statusline installed! Restart Claude Code to apply."
