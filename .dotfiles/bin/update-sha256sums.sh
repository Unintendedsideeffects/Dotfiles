#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

sha256sum "$ROOT_DIR/.dotfiles/bin/quick-install.sh" > "$ROOT_DIR/SHA256SUMS"
echo "Updated $ROOT_DIR/SHA256SUMS"
