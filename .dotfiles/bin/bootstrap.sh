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
ID_LIKE="${ID_LIKE:-}"
ID_LIKE_LOWER="${ID_LIKE,,}"

is_arch() {
  [[ "$ID_LOWER" == "arch" || "$ID_LIKE_LOWER" == *"arch"* ]]
}

is_debian_like() {
  [[ "$ID_LOWER" == "debian" || "$ID_LOWER" == "ubuntu" || "$ID_LOWER" == "linuxmint" || "$ID_LOWER" == "raspbian" || "$ID_LOWER" == "pop" || "$ID_LOWER" == "kali" || "$ID_LOWER" == "parrot" || "$ID_LOWER" == "devuan" || "$ID_LOWER" == "neon" || "$ID_LOWER" == "zorin" || "$ID_LOWER" == "mx" || "$ID_LOWER" == "nitrux" || "$ID_LOWER" == "proxmox" || "$ID_LIKE_LOWER" == *"debian"* ]]
}

is_wsl() {
  # Multiple detection methods for better reliability
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || \
  [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]] || \
  [[ -d /mnt/wsl ]] || \
  ([[ -f /proc/version ]] && grep -qi "microsoft" /proc/version && grep -qi "wsl" /proc/version) || \
  ([[ -r /proc/sys/kernel/osrelease ]] && grep -qi "microsoft" /proc/sys/kernel/osrelease 2>/dev/null && grep -qi "wsl" /proc/sys/kernel/osrelease 2>/dev/null)
}

# --- Ensure TUI dependency ---
# Helper function to run commands with sudo when needed
run_cmd() {
  if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    "$@"
  fi
}

ensure_tui() {
  if command -v whiptail >/dev/null 2>&1; then return 0; fi
  if command -v dialog >/dev/null 2>&1; then return 0; fi

  if is_arch; then
    run_cmd pacman -Sy --noconfirm --needed dialog
  elif is_debian_like; then
    run_cmd apt-get update -y
    run_cmd apt-get install -y whiptail || run_cmd apt-get install -y dialog
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
  if [[ $EUID -ne 0 ]]; then 
    sudo "$@"
  else 
    "$@"
  fi
}

# --- Debian/Ubuntu: Headless Obsidian (Xvfb/Openbox/VNC) ---
prompt_headless_obsidian() {
  local script="$BIN_DIR/bootstrap-headless-obsidian.sh"
  if [[ ! -x "$script" ]]; then
    whip --title "Headless Obsidian" --msgbox "Missing: $script" 10 70
    return 1
  fi
  "$script"
}

prompt_aur_setup() {
  if ! is_arch; then
    whip --title "AUR Setup" --msgbox "AUR helper setup is only available on Arch Linux." 10 70
    return 1
  fi

  local script="$BIN_DIR/setup-aur.sh"
  if [[ ! -x "$script" ]]; then
    whip --title "AUR Setup" --msgbox "Missing: $script" 10 70
    return 1
  fi

  if whip --title "AUR Setup" --yesno "Install yay AUR helper?\n\nThis enables installation of packages from the Arch User Repository (AUR).\n\nRequired for many development tools and applications." 15 70; then
    # Create a temporary file for output
    local tmpfile=$(mktemp)
    
    # Run script and capture output
    if "$script" >"$tmpfile" 2>&1; then
      whip --title "AUR Setup" --msgbox "yay AUR helper installed successfully!\n\nYou can now install AUR packages with:\n  yay -S package-name" 12 60
    else
      local error_output
      error_output=$(cat "$tmpfile")
      whip --title "AUR Setup Failed" --scrolltext --msgbox "$error_output" 20 80
    fi
    
    # Cleanup
    rm -f "$tmpfile"
  fi
}

prompt_packages() {
  local script="$BIN_DIR/setup-packages.sh"
  if [[ ! -x "$script" ]]; then
    whip --title "Package Installation" --msgbox "Missing: $script" 10 70
    return 1
  fi

  local package_type=""
  local distro_name=""
  
  if is_wsl; then
    if is_arch; then
      distro_name="Arch WSL"
    elif is_debian_like; then
      distro_name="Debian/Ubuntu WSL"
    else
      distro_name="WSL"
    fi
    
    if whip --title "Package Installation" --yesno "Install WSL-optimized packages for $distro_name?\n\nThis includes CLI tools plus WSL integration utilities." 12 70; then
      package_type="wsl"
    else
      return 1
    fi
  elif is_arch; then
    package_type=$(whip --title "Package Installation" --radiolist "Choose package set" 15 60 4 \
      cli "CLI tools (development/terminal)" ON \
      gui "GUI applications" OFF \
      xforward "X11 forwarding tools" OFF \
      3>&1 1>&2 2>&3) || return 1
  else
    package_type=$(whip --title "Package Installation" --radiolist "Choose package set" 15 60 3 \
      cli "CLI tools (development/terminal)" ON \
      xforward "X11 forwarding tools" OFF \
      3>&1 1>&2 2>&3) || return 1
  fi

  # For non-WSL, ask for confirmation again
  if [[ "$package_type" != "wsl" ]] && ! whip --title "Package Installation" --yesno "Install $package_type packages?\n\nThis will install development tools, utilities, and applications." 12 70; then
    return 1
  fi
  
  # Install packages while streaming output
  local tmpfile
  tmpfile=$(mktemp)
  : >"$tmpfile"
  echo "Starting package installation ($package_type)..." >>"$tmpfile"

  whip --title "Package Installation" --tailboxbg "$tmpfile" 20 80 &
  local tail_pid=$!

  local status=0
  set +e
  "$script" "$package_type" \
    > >(tee -a "$tmpfile") \
    2> >(tee -a "$tmpfile" >&2)
  status=$?
  set -e

  kill "$tail_pid" 2>/dev/null || true
  wait "$tail_pid" 2>/dev/null || true

  if [[ $status -eq 0 ]]; then
    whip --title "Package Installation" --msgbox "Package installation completed successfully!" 10 60
  else
    local output
    output=$(cat "$tmpfile")
    whip --title "Package Installation Failed" --scrolltext --msgbox "$output" 20 80
  fi

  rm -f "$tmpfile"
}

prompt_validate() {
  local script="$BIN_DIR/validate.sh"
  if [[ ! -x "$script" ]]; then
    whip --title "Validate Environment" --msgbox "Missing: $script" 10 70
    return 1
  fi

  local tmpfile
  tmpfile=$(mktemp)
  : >"$tmpfile"
  echo "Running environment validation..." >>"$tmpfile"

  whip --title "Validate Environment" --tailboxbg "$tmpfile" 20 70 &
  local tail_pid=$!

  local status=0
  set +e
  "$script" \
    > >(tee -a "$tmpfile") \
    2> >(tee -a "$tmpfile" >&2)
  status=$?
  set -e

  kill "$tail_pid" 2>/dev/null || true
  wait "$tail_pid" 2>/dev/null || true

  local output
  output=$(cat "$tmpfile")

  if [[ $status -eq 0 ]]; then
    whip --title "Validation Results" --scrolltext --msgbox "$output" 20 70
  else
    whip --title "Validation Failed" --scrolltext --msgbox "$output" 20 70
  fi

  rm -f "$tmpfile"
}

prompt_wsl_setup() {
  if ! is_wsl; then
    whip --title "WSL Setup" --msgbox "WSL setup is only available in WSL environments." 10 70
    return 1
  fi

  local script="$BIN_DIR/setup-wsl.sh"
  if [[ ! -x "$script" ]]; then
    whip --title "WSL Setup" --msgbox "Missing: $script" 10 70
    return 1
  fi

  if whip --title "WSL Setup" --yesno "Configure WSL settings (/etc/wsl.conf)?\n\nThis will:\n- Fix invalid configuration keys\n- Set up proper WSL2 settings\n- Enable systemd support" 15 70; then
    if output=$("$script" 2>&1); then
      whip --title "WSL Setup" --msgbox "WSL configuration completed.\n\nYou may need to restart WSL:\n  wsl --shutdown\n  wsl" 12 60
    else
      whip --title "WSL Setup Failed" --scrolltext --msgbox "$output" 20 80
    fi
  fi
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
    options+=("aur_setup" "Install AUR Helper (yay) [Arch]" OFF)
  fi
  
  options+=("packages" "Install Packages" OFF)
  options+=("validate" "Validate Environment" OFF)
  
  if is_wsl; then
    options+=("wsl_setup" "WSL Configuration Setup" OFF)
  fi
  if is_arch; then
    options+=("headless_gui" "Headless GUI (Xvfb/WM/VNC/Obsidian) [Arch]" OFF)
    options+=("headless_obsidian" "Headless Obsidian (Xvfb/Openbox/VNC) [Arch]" OFF)
  fi
  if is_debian_like; then
    options+=("headless_obsidian" "Headless Obsidian (Xvfb/Openbox/VNC) [Debian/Ubuntu]" OFF)
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
      aur_setup)
        prompt_aur_setup ;;
      packages)
        prompt_packages ;;
      validate)
        prompt_validate ;;
      wsl_setup)
        prompt_wsl_setup ;;
      headless_gui)
        prompt_headless_gui ;;
      headless_obsidian)
        prompt_headless_obsidian ;;
    esac
  done

  whip --title "Dotfiles Bootstrap" --msgbox "Completed selected setup steps." 10 60 || true
}

ensure_tui
main_menu
