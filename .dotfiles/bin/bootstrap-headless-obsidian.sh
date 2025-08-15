#!/usr/bin/env bash
set -euo pipefail

# Simple TUI to set up headless Obsidian

has_cmd() { command -v "$1" >/dev/null 2>&1; }

USER_NAME="${SUDO_USER:-$(whoami)}"
DISPLAY_NUM=5
VNC_PORT=5900
SCREEN="1280x800x16"
OBS_VER="1.6.7"

prompt() {
  local var="$1" prompt_msg="$2" default="$3"
  local val
  if has_cmd gum; then
    val=$(gum input --placeholder "$default" --prompt "$prompt_msg " || true)
  elif has_cmd whiptail; then
    val=$(whiptail --inputbox "$prompt_msg" 10 70 "$default" 3>&1 1>&2 2>&3 || true)
  elif has_cmd dialog; then
    val=$(dialog --inputbox "$prompt_msg" 10 70 "$default" 3>&1 1>&2 2>&3 || true)
  else
    read -rp "$prompt_msg [$default]: " val || true
  fi
  printf -v "$var" "%s" "${val:-$default}"
}

confirm() {
  if has_cmd gum; then
    gum confirm "$1"
  elif has_cmd whiptail; then
    whiptail --yesno "$1" 8 60
  elif has_cmd dialog; then
    dialog --yesno "$1" 8 60
  else
    read -rp "$1 [y/N]: " yn; [[ "${yn,,}" == y* ]]
  fi
}

if confirm "Install/enable headless Obsidian services now?"; then
  prompt USER_NAME "Linux username to run services as" "$USER_NAME"
  prompt DISPLAY_NUM "Xvfb display number" "$DISPLAY_NUM"
  prompt VNC_PORT "VNC port" "$VNC_PORT"
  prompt SCREEN "Screen geometry (WxHxDepth)" "$SCREEN"
  prompt OBS_VER "Obsidian version (tag without 'v')" "$OBS_VER"

  sudo .dotfiles/bin/install-obsidian-headless.sh \
    -u "$USER_NAME" -d "$DISPLAY_NUM" -p "$VNC_PORT" -s "$SCREEN" -o "$OBS_VER"
fi
