#!/usr/bin/env bash
set -euo pipefail

# Dotfiles bootstrap (interactive)
# Presents a TUI to select and configure optional components, similar to archinstall.
# Currently supports: Headless GUI (Arch-based) via setup-headless-gui.sh

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$DOTFILES_DIR/bin"
LIB_DIR="$DOTFILES_DIR/lib"

# shellcheck disable=SC1090
source "$LIB_DIR/detect.sh"

# Handle non-interactive dry-run calls (e.g., tests)
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    echo "Dry-run: bootstrap would launch the interactive setup UI."
    exit 0
  fi
done

# Track background processes and temp files for cleanup
declare -a CLEANUP_PIDS=()
declare -a CLEANUP_FILES=()

# Cleanup handler
cleanup_handler() {
  local exit_code=$?

  # Kill any background processes
  for pid in "${CLEANUP_PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done

  # Remove temp files
  for file in "${CLEANUP_FILES[@]}"; do
    [[ -f "$file" ]] && rm -f "$file"
  done

  exit "$exit_code"
}

# Register cleanup handler
trap cleanup_handler EXIT INT TERM

# --- Distro detection wrappers ---
is_arch() { df_is_arch; }

is_debian_like() { df_is_debian_like; }

is_rhel_like() { df_is_rhel_like; }

is_wsl() { df_is_wsl; }

# --- Helpers ---
# Helper function to run commands with sudo when needed
run_with_sudo_if_needed() {
  if [[ $EUID -ne 0 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

# --- Ensure TUI dependency ---
ensure_tui() {
  if command -v whiptail >/dev/null 2>&1; then return 0; fi
  if command -v dialog >/dev/null 2>&1; then return 0; fi

  if is_arch; then
    run_with_sudo_if_needed pacman -Sy --noconfirm --needed dialog
  elif is_debian_like; then
    run_with_sudo_if_needed apt-get update -y
    run_with_sudo_if_needed apt-get install -y whiptail || run_with_sudo_if_needed apt-get install -y dialog
  elif is_rhel_like; then
    if command -v dnf >/dev/null 2>&1; then
      run_with_sudo_if_needed dnf install -y dialog
    elif command -v yum >/dev/null 2>&1; then
      run_with_sudo_if_needed yum install -y dialog
    fi
  fi
}

whip() {
  local needs_tailboxbg=false
  for arg in "$@"; do
    if [[ "$arg" == "--tailboxbg" ]]; then
      needs_tailboxbg=true
      break
    fi
  done

  if [[ "$needs_tailboxbg" == true ]]; then
    if command -v dialog >/dev/null 2>&1; then
      dialog "$@"
      return
    fi

    local whiptail_args=()
    for arg in "$@"; do
      if [[ "$arg" == "--tailboxbg" ]]; then
        whiptail_args+=("--textbox")
      else
        whiptail_args+=("$arg")
      fi
    done
    whiptail "${whiptail_args[@]}"
    return
  fi

  if command -v whiptail >/dev/null 2>&1; then
    whiptail "$@"
  else
    dialog "$@"
  fi
}

# --- Debian/Ubuntu: Headless Obsidian (Xvfb/Openbox/VNC) ---
prompt_headless_obsidian() {
  local script="$BIN_DIR/bootstrap-headless-obsidian.sh"
  if [[ ! -f "$script" ]]; then
    whip --title "Headless Obsidian" --msgbox "Script not found: $script" 10 70
    return 1
  elif [[ ! -x "$script" ]]; then
    whip --title "Headless Obsidian" --msgbox "Script not executable: $script\n\nRun: chmod +x \"$script\"" 12 70
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
  if [[ ! -f "$script" ]]; then
    whip --title "AUR Setup" --msgbox "Script not found: $script" 10 70
    return 1
  elif [[ ! -x "$script" ]]; then
    whip --title "AUR Setup" --msgbox "Script not executable: $script\n\nRun: chmod +x \"$script\"" 12 70
    return 1
  fi

  if whip --title "AUR Setup" --yesno "Install yay AUR helper?\n\nThis enables installation of packages from the Arch User Repository (AUR).\n\nRequired for many development tools and applications." 15 70; then
    # Create a temporary file for output
    local tmpfile=$(mktemp)
    CLEANUP_FILES+=("$tmpfile")

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
  if [[ ! -f "$script" ]]; then
    whip --title "Package Installation" --msgbox "Script not found: $script" 10 70
    return 1
  elif [[ ! -x "$script" ]]; then
    whip --title "Package Installation" --msgbox "Script not executable: $script\n\nRun: chmod +x \"$script\"" 12 70
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
    package_type=$(whip --title "Package Installation" --menu "Choose package set" 15 60 4 \
      cli "CLI tools (development/terminal)" \
      gui "GUI applications" \
      xforward "X11 forwarding tools" \
      3>&1 1>&2 2>&3) || return 1
  else
    package_type=$(whip --title "Package Installation" --menu "Choose package set" 15 60 3 \
      cli "CLI tools (development/terminal)" \
      xforward "X11 forwarding tools" \
      3>&1 1>&2 2>&3) || return 1
  fi

  # For non-WSL, ask for confirmation again
  if [[ "$package_type" != "wsl" ]] && ! whip --title "Package Installation" --yesno "Install $package_type packages?\n\nThis will install development tools, utilities, and applications." 12 70; then
    return 1
  fi
  
  local preflight_output preflight_status
  preflight_output=$(USE_WHIPTAIL=1 "$script" --preflight 2>&1)
  preflight_status=$?
  if [[ $preflight_status -ne 0 ]]; then
    whip --title "Package Installation" --scrolltext --msgbox "$preflight_output" 20 80
    return 1
  fi

  local output status
  output=$("$script" --skip-preflight "$package_type" 2>&1)
  status=$?

  if [[ $status -eq 0 ]]; then
    whip --title "Package Installation" --scrolltext --msgbox "$output" 20 80
  else
    whip --title "Package Installation Failed" --scrolltext --msgbox "$output" 20 80
  fi
}

prompt_gui_autologin() {
  local script="$BIN_DIR/gui-autostart-config.sh"
  local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/gui-autostart.conf"

  if [[ ! -f "$script" ]]; then
    whip --title "GUI Autologin" --msgbox "Script not found: $script" 10 70
    return 1
  elif [[ ! -x "$script" ]]; then
    whip --title "GUI Autologin" --msgbox "Script not executable: $script\n\nRun: chmod +x \"$script\"" 12 70
    return 1
  fi

  local current_backend="x11"
  local current_command="sway"
  local enabled="0"

  if [[ -f "$config_file" ]]; then
    # shellcheck disable=SC1090
    source "$config_file"
    enabled="${AUTOLOGIN_ENABLED:-0}"
    current_backend="${SESSION_TYPE:-$current_backend}"
    current_command="${SESSION_COMMAND:-$current_command}"
  fi

  local disable_default="OFF"
  local x11_default="OFF"
  local wayland_default="OFF"

  if [[ "$enabled" != "1" ]]; then
    disable_default="ON"
  elif [[ "$current_backend" == "x11" ]]; then
    x11_default="ON"
  elif [[ "$current_backend" == "wayland" ]]; then
    wayland_default="ON"
  fi

  local disable_label x11_label wayland_label
  disable_label="Leave CLI login only (no GUI autostart)"
  x11_label="Start X11 via startx on tty1"
  wayland_label="Run a Wayland compositor command (e.g., sway)"
  if [[ "$disable_default" == "ON" ]]; then
    disable_label+=" (current)"
  elif [[ "$x11_default" == "ON" ]]; then
    x11_label+=" (current)"
  elif [[ "$wayland_default" == "ON" ]]; then
    wayland_label+=" (current)"
  fi

  local choice
  choice=$(whip --title "GUI Autologin" --menu "Choose how (or if) to auto-start a GUI session on tty1" 16 78 3 \
    disable "$disable_label" \
    x11 "$x11_label" \
    wayland "$wayland_label" \
    3>&1 1>&2 2>&3) || return 1

  local output

  case "$choice" in
    disable)
      output=$("$script" disable 2>&1) || {
        whip --title "GUI Autologin" --scrolltext --msgbox "$output" 20 80
        return 1
      }
      whip --title "GUI Autologin" --msgbox "GUI autostart disabled.\n\nYou will stay in the CLI unless you start a GUI manually." 12 70
      ;;
    x11)
      output=$("$script" enable --backend x11 2>&1) || {
        whip --title "GUI Autologin" --scrolltext --msgbox "$output" 20 80
        return 1
      }
      whip --title "GUI Autologin" --msgbox "Configured startx to run automatically on tty1.\n\nIf X11 exits or fails you will drop back to the shell." 12 70
      ;;
    wayland)
      local cmd_input
      cmd_input=$(whip --title "GUI Autologin" --inputbox "Wayland launch command\n(e.g., sway, dbus-run-session hyprland)" 12 75 "$current_command" 3>&1 1>&2 2>&3) || return 1
      if [[ -z "$cmd_input" ]]; then
        whip --title "GUI Autologin" --msgbox "Wayland command cannot be empty." 10 70
        return 1
      fi
      output=$("$script" enable --backend wayland --command "$cmd_input" 2>&1) || {
        whip --title "GUI Autologin" --scrolltext --msgbox "$output" 20 80
        return 1
      }
      whip --title "GUI Autologin" --msgbox "Configured Wayland autostart.\n\nIf the compositor exits you will return to the shell." 12 70
      ;;
  esac
}

prompt_validate() {
  local script="$BIN_DIR/validate.sh"
  if [[ ! -f "$script" ]]; then
    whip --title "Validate Environment" --msgbox "Script not found: $script" 10 70
    return 1
  elif [[ ! -x "$script" ]]; then
    whip --title "Validate Environment" --msgbox "Script not executable: $script\n\nRun: chmod +x \"$script\"" 12 70
    return 1
  fi

  local tmpfile
  tmpfile=$(mktemp)
  CLEANUP_FILES+=("$tmpfile")
  : >"$tmpfile"
  echo "Running environment validation..." >>"$tmpfile"

  whip --title "Validate Environment" --tailboxbg "$tmpfile" 20 70 &
  local tail_pid=$!
  CLEANUP_PIDS+=("$tail_pid")

  local status=0
  # Run script and capture all output to tmpfile
  # Using exec redirection to avoid process substitution issues
  {
    "$script" 2>&1
    echo "$?" > "${tmpfile}.status"
  } >> "$tmpfile" || true

  status=$(cat "${tmpfile}.status" 2>/dev/null || echo "1")
  rm -f "${tmpfile}.status"
  CLEANUP_FILES+=("${tmpfile}.status")

  # Kill background process with timeout
  if kill "$tail_pid" 2>/dev/null; then
    local timeout=5
    while kill -0 "$tail_pid" 2>/dev/null && ((timeout > 0)); do
      sleep 0.1
      ((timeout--))
    done
    kill -9 "$tail_pid" 2>/dev/null || true
  fi
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

prompt_git_config() {
  # Try to get git config from environment, existing git config, or .gitconfig.local
  local default_username="${GIT_USER_NAME:-$(git config --global user.name 2>/dev/null || echo "")}"
  local default_email="${GIT_USER_EMAIL:-$(git config --global user.email 2>/dev/null || echo "")}"

  # Check if .gitconfig.local already exists and use those values as defaults
  if [[ -f "$HOME/.gitconfig.local" ]]; then
    local existing_name
    local existing_email
    existing_name=$(git config --file "$HOME/.gitconfig.local" user.name 2>/dev/null || echo "")
    existing_email=$(git config --file "$HOME/.gitconfig.local" user.email 2>/dev/null || echo "")

    if [[ -n "$existing_name" ]]; then
      default_username="$existing_name"
    fi
    if [[ -n "$existing_email" ]]; then
      default_email="$existing_email"
    fi
  fi

  # Always show TUI prompts with pre-populated defaults
  local git_username
  git_username=$(whip --title "Git Configuration" --inputbox "Enter your Git username:" 10 60 "$default_username" 3>&1 1>&2 2>&3)
  if [[ $? -ne 0 ]]; then
    whip --title "Git Configuration" --msgbox "Git configuration cancelled." 10 60
    return 1
  fi

  # Trim whitespace and validate
  git_username="${git_username#"${git_username%%[![:space:]]*}"}"
  git_username="${git_username%"${git_username##*[![:space:]]}"}"

  if [[ -z "$git_username" ]]; then
    whip --title "Git Configuration" --msgbox "Git username cannot be empty." 10 60
    return 1
  fi

  local git_email
  git_email=$(whip --title "Git Configuration" --inputbox "Enter your Git email:" 10 60 "$default_email" 3>&1 1>&2 2>&3)
  if [[ $? -ne 0 ]]; then
    whip --title "Git Configuration" --msgbox "Git configuration cancelled." 10 60
    return 1
  fi

  # Trim whitespace and validate
  git_email="${git_email#"${git_email%%[![:space:]]*}"}"
  git_email="${git_email%"${git_email##*[![:space:]]}"}"

  if [[ -z "$git_email" ]]; then
    whip --title "Git Configuration" --msgbox "Git email cannot be empty." 10 60
    return 1
  fi

  # Confirm configuration
  if ! whip --title "Git Configuration" --yesno "Save the following configuration?\n\nName: $git_username\nEmail: $git_email" 12 70; then
    return 0
  fi

  # Create .gitconfig.local
  cat > "$HOME/.gitconfig.local" <<EOF
# Local Git Configuration
# This file was automatically created during dotfiles setup
# Edit this file to update your git user information

[user]
	name = $git_username
	email = $git_email

# Optional: Configure GPG signing
# [commit]
# 	gpgsign = true
# [user]
# 	signingkey = YOUR_GPG_KEY_ID

# Optional: Add any other local overrides here
EOF

  whip --title "Git Configuration" --msgbox "Git configuration saved to ~/.gitconfig.local\n\nName: $git_username\nEmail: $git_email" 12 60
}

prompt_wsl_setup() {
  if ! is_wsl; then
    whip --title "WSL Setup" --msgbox "WSL setup is only available in WSL environments." 10 70
    return 1
  fi

  local script="$BIN_DIR/setup-wsl.sh"
  if [[ ! -f "$script" ]]; then
    whip --title "WSL Setup" --msgbox "Script not found: $script" 10 70
    return 1
  elif [[ ! -x "$script" ]]; then
    whip --title "WSL Setup" --msgbox "Script not executable: $script\n\nRun: chmod +x \"$script\"" 12 70
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

prompt_locale_setup() {
  local script="$BIN_DIR/setup-locale.sh"
  if [[ ! -f "$script" ]]; then
    whip --title "Locale Setup" --msgbox "Script not found: $script" 10 70
    return 1
  elif [[ ! -x "$script" ]]; then
    whip --title "Locale Setup" --msgbox "Script not executable: $script\n\nRun: chmod +x \"$script\"" 12 70
    return 1
  fi

  if whip --title "Locale Setup" --yesno "Configure UTF-8 locale?\n\nStarship and other tools require UTF-8 locale support.\n\nThis will:\n- Check if UTF-8 locale is available\n- Generate en_US.UTF-8 if needed\n- Set system locale to UTF-8\n\nSupports Arch, Debian/Ubuntu, and RHEL-based systems." 18 70; then
    local tmpfile
    tmpfile=$(mktemp)
    CLEANUP_FILES+=("$tmpfile")
    : >"$tmpfile"
    echo "Checking locale configuration..." >>"$tmpfile"

    whip --title "Locale Setup" --tailboxbg "$tmpfile" 20 80 &
    local tail_pid=$!
    CLEANUP_PIDS+=("$tail_pid")

    local status=0
    {
      "$script" setup 2>&1
      echo "$?" > "${tmpfile}.status"
    } >> "$tmpfile" || true

    status=$(cat "${tmpfile}.status" 2>/dev/null || echo "1")
    rm -f "${tmpfile}.status"
    CLEANUP_FILES+=("${tmpfile}.status")

    # Kill background process with timeout
    if kill "$tail_pid" 2>/dev/null; then
      local timeout=5
      while kill -0 "$tail_pid" 2>/dev/null && ((timeout > 0)); do
        sleep 0.1
        ((timeout--))
      done
      kill -9 "$tail_pid" 2>/dev/null || true
    fi
    wait "$tail_pid" 2>/dev/null || true

    local output
    output=$(cat "$tmpfile")

    if [[ $status -eq 0 ]]; then
      whip --title "Locale Setup" --scrolltext --msgbox "$output\n\nYou may need to log out and back in for changes to take effect.\nOr run: export LANG=en_US.UTF-8" 20 80
    else
      whip --title "Locale Setup Failed" --scrolltext --msgbox "$output" 20 80
    fi

    rm -f "$tmpfile"
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

  wm_choice=$(whip --title "Headless GUI" --menu "Choose window manager" 15 60 3 \
    openbox "Openbox (lightweight)" \
    i3 "i3 (tiling)" \
    3>&1 1>&2 2>&3) || return 1

  if whip --title "Headless GUI" --yesno "Enable VNC server?" 10 60; then vnc_enabled=true; else vnc_enabled=false; fi
  if whip --title "Headless GUI" --yesno "Install and run Obsidian?" 10 60; then obsidian_enabled=true; else obsidian_enabled=false; fi

  # Validate display number
  while true; do
    display_num=$(whip --title "Headless GUI" --inputbox "X display number (format :N)" 10 60 ":5" 3>&1 1>&2 2>&3) || return 1
    if [[ "$display_num" =~ ^:[0-9]+$ ]]; then
      break
    else
      whip --title "Invalid Input" --msgbox "Display number must be in format :N where N is a number (e.g., :5)" 10 60
    fi
  done

  # Validate VNC port
  while true; do
    vnc_port=$(whip --title "Headless GUI" --inputbox "VNC port" 10 60 "5900" 3>&1 1>&2 2>&3) || return 1
    if [[ "$vnc_port" =~ ^[0-9]+$ ]] && ((vnc_port >= 1 && vnc_port <= 65535)); then
      break
    else
      whip --title "Invalid Input" --msgbox "VNC port must be a number between 1 and 65535" 10 60
    fi
  done

  # Validate target user
  while true; do
    target_user=$(whip --title "Headless GUI" --inputbox "Target user" 10 60 "$default_user" 3>&1 1>&2 2>&3) || return 1
    if [[ "$target_user" =~ ^[a-z_][a-z0-9_-]*\$?$ ]] && id "$target_user" >/dev/null 2>&1; then
      break
    else
      whip --title "Invalid Input" --msgbox "User '$target_user' does not exist or is invalid" 10 60
    fi
  done

  local script="$BIN_DIR/setup-headless-gui.sh"
  if [[ ! -f "$script" ]]; then
    whip --title "Headless GUI" --msgbox "Script not found: $script" 10 70
    return 1
  elif [[ ! -x "$script" ]]; then
    whip --title "Headless GUI" --msgbox "Script not executable: $script\n\nRun: chmod +x \"$script\"" 12 70
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
  options+=("git_config" "Configure Git User Settings" OFF)
  options+=("locale_setup" "Configure UTF-8 Locale (for Starship)" OFF)

  if is_arch; then
    options+=("aur_setup" "Install AUR Helper (yay) [Arch]" OFF)
  fi

  options+=("packages" "Install Packages" OFF)
  options+=("gui_autologin" "Configure GUI autostart (X11/Wayland)" OFF)
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

  # Parse whiptail's space-separated quoted output into array
  local selection_array=()
  eval "selection_array=($selections)"

  # Process each selection
  for sel in "${selection_array[@]}"; do
    case "$sel" in
      git_config)
        prompt_git_config ;;
      locale_setup)
        prompt_locale_setup ;;
      aur_setup)
        prompt_aur_setup ;;
      packages)
        prompt_packages ;;
      gui_autologin)
        prompt_gui_autologin ;;
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
