#!/usr/bin/env bash

# Start X only when called explicitly on the first virtual terminal.

set -euo pipefail

if [[ -n "${DISPLAY:-}" ]]; then
  exit 0
fi

if [[ "${XDG_VTNR:-}" != "1" ]]; then
  exit 0
fi

if ! command -v startx >/dev/null 2>&1; then
  echo "startx command not found in PATH." >&2
  exit 1
fi

if ! startx "$@"; then
  echo "startx exited with a non-zero status." >&2
  exit 1
fi
