#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "== Validate script =="
"$ROOT_DIR/.dotfiles/bin/validate.sh" || true

echo "== Bootstrap dry-run =="
"$ROOT_DIR/.dotfiles/bin/bootstrap.sh" --dry-run || true

echo "== X-forwarding dry-run =="
"$ROOT_DIR/.dotfiles/bin/setup-xforward.sh" --dry-run || true

echo "All dry-runs completed."

