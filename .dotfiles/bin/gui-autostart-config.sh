#!/usr/bin/env bash

set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
CONFIG_FILE="$CONFIG_DIR/gui-autostart.conf"

usage() {
  cat <<'EOF'
Usage:
  gui-autostart-config.sh enable --backend <x11|wayland> [--command "<launch command>"]
  gui-autostart-config.sh disable
  gui-autostart-config.sh status
EOF
}

write_config() {
  local backend="$1"
  local command="$2"

  mkdir -p "$CONFIG_DIR"

  {
    echo "AUTOLOGIN_ENABLED=1"
    echo "SESSION_TYPE=$backend"
    printf 'SESSION_COMMAND=%q\n' "$command"
  } >"$CONFIG_FILE"
}

cmd_enable() {
  local backend=""
  local command=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --backend)
        backend="$2"
        shift 2
        ;;
      --command)
        command="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  if [[ "$backend" != "x11" && "$backend" != "wayland" ]]; then
    echo "Backend must be 'x11' or 'wayland'." >&2
    exit 1
  fi

  if [[ "$backend" == "wayland" && -z "$command" ]]; then
    echo "Wayland backend requires a command (e.g., 'sway' or 'dbus-run-session hyprland')." >&2
    exit 1
  fi

  write_config "$backend" "$command"
  echo "GUI autostart enabled for backend: $backend"
}

cmd_disable() {
  if [[ -f "$CONFIG_FILE" ]]; then
    rm -f "$CONFIG_FILE"
    echo "GUI autostart disabled."
  else
    echo "GUI autostart is already disabled."
  fi
}

cmd_status() {
  if [[ -f "$CONFIG_FILE" ]]; then
    cat "$CONFIG_FILE"
  else
    echo "GUI autostart not configured."
  fi
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  local subcmd="$1"
  shift

  case "$subcmd" in
    enable)
      cmd_enable "$@"
      ;;
    disable)
      cmd_disable
      ;;
    status)
      cmd_status
      ;;
    *)
      echo "Unknown command: $subcmd" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
