#!/usr/bin/env bash

set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
CONFIG_FILE="$CONFIG_DIR/gui-autostart.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

enabled="${AUTOLOGIN_ENABLED:-0}"
session_type="${SESSION_TYPE:-none}"
session_command="${SESSION_COMMAND:-}"

if [[ "$enabled" != "1" ]]; then
  exit 0
fi

# Require a local console session without an existing display server
if [[ "${XDG_VTNR:-}" != "1" ]]; then
  exit 0
fi

if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
  exit 0
fi

log_notice() {
  if [[ "${DOTFILES_GUI_AUTOSTART_DEBUG:-0}" = "1" ]]; then
    printf '%s\n' "$1" >&2
  fi
}

run_wayland_session() {
  local cmd="$1"
  if [[ -z "$cmd" ]]; then
    echo "Wayland command is not configured." >&2
    return 1
  fi

  # Grab the first token to check availability
  local first_token
  read -r first_token _ <<<"$cmd"

  if [[ -n "$first_token" ]] && ! command -v "$first_token" >/dev/null 2>&1; then
    if [[ ! -x "$first_token" && ! -x "$cmd" ]]; then
      printf "Configured Wayland command '%s' is not executable.\n" "$cmd" >&2
      return 1
    fi
  fi

  if ! bash -lc "$cmd"; then
    printf "Wayland command '%s' exited abnormally.\n" "$cmd" >&2
    return 1
  fi
}

case "$session_type" in
  x11)
    if ! "$SCRIPT_DIR/startx-if-tty1.sh" ${session_command:+$session_command}; then
      echo "Failed to start the X11 session (see logs above)." >&2
      sleep 2
    fi
    ;;
  wayland)
    if ! run_wayland_session "$session_command"; then
      echo "Failed to start the Wayland session (see logs above)." >&2
      sleep 2
    fi
    ;;
  none|"" )
    log_notice "GUI autostart disabled via configuration."
    ;;
  *)
    printf "Unknown session type '%s' in %s\n" "$session_type" "$CONFIG_FILE" >&2
    ;;
esac
