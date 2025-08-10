#!/usr/bin/env bash
set -euo pipefail

# Dotfiles bootstrap (interactive)
# Presents a TUI to select and configure optional components, similar to archinstall.
# Currently supports: Headless GUI (Arch-based) via setup-headless-gui.sh

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$DOTFILES_DIR/bin"

# --- Distro detection ---
. /etc/os-release
ID_LOWER="${ID,,}"
ID_LIKE_LOWER="${ID_LIKE:-}" ; ID_LIKE_LOWER="${ID_LIKE_LOWER,,}"

is_arch() {
  [[ "$ID_LOWER" == "arch" || "$ID_LIKE_LOWER" == *"arch"* ]]
}

is_debian_like() {
  [[ "$ID_LOWER" == "debian" || "$ID_LOWER" == "ubuntu" || "$ID_LOWER" == "linuxmint" || "$ID_LOWER" == "raspbian" || "$ID_LOWER" == "pop" || "$ID_LOWER" == "kali" || "$ID_LOWER" == "parrot" || "$ID_LOWER" == "devuan" || "$ID_LOWER" == "neon" || "$ID_LOWER" == "zorin" || "$ID_LOWER" == "mx" || "$ID_LOWER" == "nitrux" || "$ID_LOWER" == "proxmox" || "$ID_LIKE_LOWER" == *"debian"* ]]
}

# --- Ensure TUI dependency ---
ensure_tui() {
  if command -v whiptail >/dev/null 2>&1; then return 0; fi
  if command -v dialog >/dev/null 2>&1; then return 0; fi

  if is_arch; then
    sudo pacman -Sy --noconfirm --needed dialog
  elif is_debian_like; then
    sudo apt-get update -y
    sudo apt-get install -y whiptail || sudo apt-get install -y dialog
  fi
}

whip() {
  if command -v whiptail >/dev/null 2>&1; then
    whiptail "$@"
  else
    dialog "$@"
  fi
}

# --- Helpers ---
run_with_sudo_if_needed() {
  if [[ $EUID -ne 0 ]]; then sudo "$@"; else "$@"; fi
}

prompt_headless_gui() {
  # Only available on Arch-based systems because setup-headless-gui.sh is Arch-specific
  if ! is_arch; then
    whip --title "Headless GUI" --msgbox "Headless GUI setup is currently implemented for Arch-based systems only." 10 70
    return 1
  fi

  local default_user
  default_user="${SUDO_USER:-${USER}}"

  local wm_choice vnc_enabled obsidian_enabled display_num vnc_port target_user

  wm_choice=$(whip --title "Headless GUI" --radiolist "Choose window manager" 15 60 3 \
    openbox "Openbox (lightweight)" ON \
    i3 "i3 (tiling)" OFF \
    3>&1 1>&2 2>&3) || return 1

  if whip --title "Headless GUI" --yesno "Enable VNC server?" 10 60; then vnc_enabled=true; else vnc_enabled=false; fi
  if whip --title "Headless GUI" --yesno "Install and run Obsidian?" 10 60; then obsidian_enabled=true; else obsidian_enabled=false; fi

  display_num=$(whip --title "Headless GUI" --inputbox "X display number (format :N)" 10 60 ":5" 3>&1 1>&2 2>&3) || return 1
  vnc_port=$(whip --title "Headless GUI" --inputbox "VNC port" 10 60 "5900" 3>&1 1>&2 2>&3) || return 1
  target_user=$(whip --title "Headless GUI" --inputbox "Target user" 10 60 "$default_user" 3>&1 1>&2 2>&3) || return 1

  local script="$BIN_DIR/setup-headless-gui.sh"
  if [[ ! -x "$script" ]]; then
    whip --title "Headless GUI" --msgbox "Missing: $script" 10 70
    return 1
  fi

  run_with_sudo_if_needed bash "$script" \
    --wm "$wm_choice" \
    --enable-vnc "$vnc_enabled" \
    --obsidian "$obsidian_enabled" \
    --display "$display_num" \
    --vnc-port "$vnc_port" \
    --user "$target_user"
}

main_menu() {
  local options=()

  # Dynamically include options based on available scripts and distro
  if is_arch; then
    options+=("headless_gui" "Headless GUI (Xvfb/WM/VNC/Obsidian) [Arch]" OFF)
  fi

  if [[ ${#options[@]} -eq 0 ]]; then
    whip --title "Dotfiles Bootstrap" --msgbox "No interactive components available for this distro." 10 70
    exit 0
  fi

  local selections
  selections=$(whip --title "Dotfiles Bootstrap" --checklist "Select components to configure" 20 80 10 \
    "${options[@]}" \
    3>&1 1>&2 2>&3) || exit 1

  # Separate-output not used; parse quoted selections
  for sel in $selections; do
    sel=${sel//\"/}
    case "$sel" in
      headless_gui)
        prompt_headless_gui ;;
    esac
  done

  whip --title "Dotfiles Bootstrap" --msgbox "Completed selected setup steps." 10 60 || true
}

ensure_tui
main_menu
