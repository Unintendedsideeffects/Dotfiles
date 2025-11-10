#!/usr/bin/env bash

# Start X only when called explicitly on the first virtual terminal.

set -euo pipefail

if [[ -n "${DISPLAY:-}" ]]; then
  echo "DISPLAY already set; refusing to start another X session." >&2
  exit 0
fi

if [[ "${XDG_VTNR:-}" != "1" ]]; then
  echo "Not on tty1; stop to avoid taking over other consoles." >&2
  exit 0
fi

exec startx "$@"
