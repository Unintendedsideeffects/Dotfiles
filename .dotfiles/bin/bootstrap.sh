#!/usr/bin/env bash
set -euo pipefail

# Dotfiles bootstrap (interactive)
# Presents a TUI to select and configure optional components, similar to archinstall.
# Currently supports: Headless GUI (Arch-based) via setup-headless-gui.sh

export NEWT_COLORS='root=white,black;border=white,black;window=white,black;shadow=white,black;title=white,black;button=black,white;actbutton=white,black;checkbox=white,black;actcheckbox=black,white;entry=white,black;label=white,black;listbox=white,black;actlistbox=black,white;textbox=white,black;helpline=white,black;roottext=white,black'

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

# Force monochrome dialog when whiptail is unavailable.
DIALOGRC_PATH=$(mktemp)
CLEANUP_FILES+=("$DIALOGRC_PATH")
cat >"$DIALOGRC_PATH" <<'EOF'
use_shadow = OFF
use_colors = ON
screen_color = (WHITE,BLACK,OFF)
shadow_color = (WHITE,BLACK,OFF)
dialog_color = (WHITE,BLACK,OFF)
title_color = (WHITE,BLACK,OFF)
border_color = (WHITE,BLACK,OFF)
button_active_color = (BLACK,WHITE,OFF)
button_inactive_color = (WHITE,BLACK,OFF)
button_key_active_color = (BLACK,WHITE,OFF)
button_key_inactive_color = (WHITE,BLACK,OFF)
button_label_active_color = (BLACK,WHITE,OFF)
button_label_inactive_color = (WHITE,BLACK,OFF)
checkbox_color = (WHITE,BLACK,OFF)
checkbox_focus_color = (BLACK,WHITE,OFF)
listbox_color = (WHITE,BLACK,OFF)
listbox_focus_color = (BLACK,WHITE,OFF)
entry_color = (WHITE,BLACK,OFF)
entry_focus_color = (BLACK,WHITE,OFF)
tag_color = (WHITE,BLACK,OFF)
tag_focus_color = (BLACK,WHITE,OFF)
item_color = (WHITE,BLACK,OFF)
item_focus_color = (BLACK,WHITE,OFF)
EOF
export DIALOGRC="$DIALOGRC_PATH"

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
# Helper function to check for commands with extended PATH
# /usr/sbin is not in default PATH for non-root users on Debian
command_exists() {
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH" command -v "$1" >/dev/null 2>&1
}

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
  if command_exists whiptail; then return 0; fi
  if command_exists dialog; then return 0; fi

  if is_arch; then
    run_with_sudo_if_needed pacman -Sy --noconfirm --needed dialog
  elif is_debian_like; then
    run_with_sudo_if_needed apt-get update -y
    run_with_sudo_if_needed apt-get install -y whiptail || run_with_sudo_if_needed apt-get install -y dialog
  elif is_rhel_like; then
    if command_exists dnf; then
      run_with_sudo_if_needed dnf install -y dialog
    elif command_exists yum; then
      run_with_sudo_if_needed yum install -y dialog
    fi
  fi
}

whip() {
  local needs_tailboxbg=false
  local nonfatal=false
  for arg in "$@"; do
    case "$arg" in
      --tailboxbg)
        needs_tailboxbg=true
        nonfatal=true
        ;;
      --msgbox|--textbox|--infobox|--tailbox)
        nonfatal=true
        ;;
    esac
  done

  local rc=0
  local errexit_was_set=0
  case $- in *e*) errexit_was_set=1 ;; esac
  set +e

  if [[ "$needs_tailboxbg" == true ]]; then
    if command_exists dialog; then
      PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH" dialog "$@"
      rc=$?
    else
      local whiptail_args=()
      for arg in "$@"; do
        if [[ "$arg" == "--tailboxbg" ]]; then
          whiptail_args+=("--textbox")
        else
          whiptail_args+=("$arg")
        fi
      done
      PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH" whiptail "${whiptail_args[@]}"
      rc=$?
    fi
  else
    if command_exists whiptail; then
      PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH" whiptail "$@"
      rc=$?
    else
      PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH" dialog "$@"
      rc=$?
    fi
  fi

  if ((errexit_was_set)); then
    set -e
  fi

  if [[ "$nonfatal" == true ]]; then
    return 0
  fi

  return "$rc"
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

  # Check if running as root (not via sudo, but actual root user)
  local actual_user="${SUDO_USER:-$USER}"
  if [[ "$actual_user" == "root" ]] || [[ $EUID -eq 0 && -z "${SUDO_USER:-}" ]]; then
    whip --title "AUR Setup" --msgbox "ERROR: Cannot install yay as root user.\n\nAUR helpers should not be run as root for security reasons.\n\nPlease:\n  1. Create a regular user account\n  2. Log in as that user\n  3. Run the bootstrap again" 16 70
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
      whip --title "AUR Setup Failed" --msgbox "$error_output" 20 80
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
      whip --title "Package Installation" --msgbox "Package installation skipped." 10 60 || true
      return 0
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
    whip --title "Package Installation" --msgbox "Package installation skipped." 10 60 || true
    return 0
  fi
  
  local preflight_output preflight_status
  preflight_output=$(USE_WHIPTAIL=1 bash "$script" --preflight 2>&1)
  preflight_status=$?
  if [[ $preflight_status -ne 0 ]]; then
    whip --title "Package Installation" --msgbox "$preflight_output" 20 80
    return 0
  fi

  local output status tmpfile
  tmpfile=$(mktemp)
  CLEANUP_FILES+=("$tmpfile")

  set +e
  bash "$script" --skip-preflight "$package_type" 2>&1 | tee "$tmpfile"
  status=${PIPESTATUS[0]}
  set -e

  if [[ $status -eq 0 ]]; then
    whip --title "Package Installation" --msgbox "Package installation completed.\n\nLog file:\n$tmpfile" 12 70
  else
    output=$(tail -n 200 "$tmpfile" 2>/dev/null || true)
    whip --title "Package Installation Failed" --msgbox "${output:-Package installation failed. Log file:\n$tmpfile}" 20 80
  fi

  return 0
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
        whip --title "GUI Autologin" --msgbox "$output" 20 80
        return 1
      }
      whip --title "GUI Autologin" --msgbox "GUI autostart disabled.\n\nYou will stay in the CLI unless you start a GUI manually." 12 70
      ;;
    x11)
      output=$("$script" enable --backend x11 2>&1) || {
        whip --title "GUI Autologin" --msgbox "$output" 20 80
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
        whip --title "GUI Autologin" --msgbox "$output" 20 80
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
    whip --title "Validation Results" --msgbox "$output" 20 70
  else
    whip --title "Validation Failed" --msgbox "$output" 20 70
  fi

  rm -f "$tmpfile"
}

prompt_claude_statusline() {
  local script="$DOTFILES_DIR/claude/install.sh"
  if [[ ! -f "$script" ]]; then
    whip --title "Claude Statusline" --msgbox "Script not found: $script" 10 70
    return 1
  elif [[ ! -x "$script" ]]; then
    whip --title "Claude Statusline" --msgbox "Script not executable: $script\n\nRun: chmod +x \"$script\"" 12 70
    return 1
  fi

  if whip --title "Claude Statusline" --yesno "Install Claude Code statusline configuration?\n\nThis will:\n- Copy statusline-command.sh to ~/.claude\n- Install settings.json if missing\n\nRequires: jq" 16 70; then
    local output
    if output=$("$script" 2>&1); then
      whip --title "Claude Statusline" --msgbox "$output" 18 70
    else
      whip --title "Claude Statusline Failed" --msgbox "$output" 20 80
    fi
  fi
}

prompt_create_user() {
  # Check if we have permission to create users
  if [[ $EUID -ne 0 ]]; then
    whip --title "Create User" --msgbox "ERROR: This option requires root privileges.\n\nPlease run the bootstrap as root or with sudo." 12 70
    return 1
  fi

  # Check if required commands are available
  if ! command_exists useradd || ! command_exists usermod || ! command_exists visudo; then
    whip --title "Create User" --msgbox "ERROR: Required commands not available.\n\nMissing one or more of: useradd, usermod, visudo\n\nThese commands are typically in /usr/sbin." 14 70
    return 1
  fi

  # Get username
  local new_username
  if ! new_username=$(whip --title "Create User" --inputbox "Enter username for new user:\n\n(lowercase letters, numbers, underscore, hyphen)" 12 60 "" 3>&1 1>&2 2>&3); then
    return 1
  fi

  # Validate username
  if [[ -z "$new_username" ]]; then
    whip --title "Create User" --msgbox "ERROR: Username cannot be empty." 10 60
    return 1
  fi

  if ! [[ "$new_username" =~ ^[a-z_][a-z0-9_-]*\$?$ ]]; then
    whip --title "Create User" --msgbox "ERROR: Invalid username.\n\nUse lowercase letters, numbers, underscore, and hyphen.\nMust start with a letter or underscore." 12 60
    return 1
  fi

  # Check if user already exists
  if id "$new_username" >/dev/null 2>&1; then
    whip --title "Create User" --msgbox "ERROR: User '$new_username' already exists." 10 60
    return 1
  fi

  if [[ "$new_username" == "root" ]]; then
    whip --title "Create User" --msgbox "ERROR: Cannot create a user named 'root'." 10 60
    return 1
  fi

  # Confirm creation
  if ! whip --title "Create User" --yesno "Create user: $new_username?\n\nThe user will be created with:\n- Home directory: /home/$new_username\n- Default shell: /bin/bash\n- Sudo access (requires password)\n\nContinue?" 14 70; then
    return 0
  fi

  # Create the user
  if ! useradd -m -s /bin/bash "$new_username" 2>/dev/null; then
    whip --title "Create User" --msgbox "ERROR: Failed to create user '$new_username'\n\nCheck system logs for details." 12 70
    return 1
  fi

  # Set password
  whip --title "Create User" --msgbox "Next, you will be prompted to set a password for $new_username.\n\nPress OK to continue." 10 70
  
  if ! passwd "$new_username"; then
    whip --title "Create User" --msgbox "WARNING: User '$new_username' was created but password setup failed.\n\nYou can set the password manually with:\n  passwd $new_username" 12 70
  fi

  # Add to sudo group
  local sudo_success=false
  if usermod -aG sudo "$new_username" 2>/dev/null; then
    sudo_success=true
  elif usermod -aG wheel "$new_username" 2>/dev/null; then
    sudo_success=true
  fi

  if [[ "$sudo_success" == true ]]; then
    # Ask about passwordless sudo
    if whip --title "Create User" --yesno "User '$new_username' created successfully!\n\nWould you like to enable passwordless sudo?\n\nWARNING: This allows $new_username to run commands as root without a password.\n\nThis is convenient but reduces security.\nOnly enable on trusted systems.\n\nEnable passwordless sudo?" 18 70; then
      # Create sudoers entry
      local sudoers_entry="$new_username ALL=(ALL) NOPASSWD:ALL"
      local temp_sudoers=$(mktemp)

      echo "$sudoers_entry" > "$temp_sudoers"
      chmod 0440 "$temp_sudoers"

      # Validate with visudo
      if ! visudo -c -f "$temp_sudoers" >/dev/null 2>&1; then
        rm -f "$temp_sudoers"
        whip --title "Create User" --msgbox "ERROR: Invalid sudoers syntax. This should not happen.\n\nPasswordless sudo was not configured." 12 70
      else
        # Move to sudoers.d
        if mv "$temp_sudoers" "/etc/sudoers.d/$new_username"; then
          whip --title "Create User" --msgbox "SUCCESS!\n\nUser '$new_username' created with passwordless sudo.\n\nConfiguration: /etc/sudoers.d/$new_username" 12 70
        else
          rm -f "$temp_sudoers"
          whip --title "Create User" --msgbox "ERROR: Failed to create sudoers configuration.\n\nUser was created but passwordless sudo was not configured." 12 70
        fi
      fi
    else
      whip --title "Create User" --msgbox "SUCCESS!\n\nUser '$new_username' created with sudo access.\n\nThe user will need to enter their password for sudo commands." 12 70
    fi
  else
    whip --title "Create User" --msgbox "WARNING: User '$new_username' was created but could not be added to sudo/wheel group.\n\nYour system may use a different group for sudo access.\n\nManual configuration may be required." 14 70
    return 1
  fi
}

prompt_passwordless_sudo() {
  # Check if we have permission to modify sudoers
  if [[ $EUID -ne 0 ]]; then
    whip --title "Passwordless Sudo" --msgbox "ERROR: This option requires root privileges.\n\nPlease run the bootstrap as root or with sudo." 12 70
    return 1
  fi

  # Determine target user
  local target_user="${SUDO_USER:-}"
  if [[ -z "$target_user" || "$target_user" == "root" ]]; then
    # Running as actual root, ask which user
    if ! target_user=$(whip --title "Passwordless Sudo" --inputbox "Enter username to grant passwordless sudo:" 10 60 "" 3>&1 1>&2 2>&3); then
      return 1
    fi
    if [[ -z "$target_user" ]]; then
      return 1
    fi

    # Validate user exists
    if ! id "$target_user" >/dev/null 2>&1; then
      whip --title "Passwordless Sudo" --msgbox "ERROR: User '$target_user' does not exist." 10 60
      return 1
    fi

    if [[ "$target_user" == "root" ]]; then
      whip --title "Passwordless Sudo" --msgbox "ERROR: Cannot configure passwordless sudo for root user.\n\nRoot already has all permissions." 12 60
      return 1
    fi
  fi

  # Check if already configured
  if [[ -f "/etc/sudoers.d/$target_user" ]]; then
    if grep -q "NOPASSWD:ALL" "/etc/sudoers.d/$target_user" 2>/dev/null; then
      whip --title "Passwordless Sudo" --msgbox "User '$target_user' already has passwordless sudo configured.\n\nFile: /etc/sudoers.d/$target_user" 12 70
      return 0
    fi
  fi

  # Show warning and confirm
  if ! whip --title "Passwordless Sudo" --yesno "Enable passwordless sudo for user: $target_user?\n\nWARNING: This allows $target_user to run any command as root without entering a password.\n\nThis is convenient but reduces security.\nOnly enable on trusted systems.\n\nContinue?" 16 70; then
    return 0
  fi

  # Create sudoers entry
  local sudoers_entry="$target_user ALL=(ALL) NOPASSWD:ALL"
  local temp_sudoers=$(mktemp)

  echo "$sudoers_entry" > "$temp_sudoers"
  chmod 0440 "$temp_sudoers"

  # Validate with visudo
  if ! visudo -c -f "$temp_sudoers" >/dev/null 2>&1; then
    rm -f "$temp_sudoers"
    whip --title "Passwordless Sudo" --msgbox "ERROR: Invalid sudoers syntax. This should not happen.\n\nPlease report this issue." 12 70
    return 1
  fi

  # Move to sudoers.d
  if mv "$temp_sudoers" "/etc/sudoers.d/$target_user"; then
    whip --title "Passwordless Sudo" --msgbox "SUCCESS: Passwordless sudo enabled for $target_user\n\nConfiguration file: /etc/sudoers.d/$target_user\n\nThe user can now run sudo commands without a password." 14 70
  else
    rm -f "$temp_sudoers"
    whip --title "Passwordless Sudo" --msgbox "ERROR: Failed to create /etc/sudoers.d/$target_user\n\nCheck permissions and try again." 12 70
    return 1
  fi
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
  if ! git_username=$(whip --title "Git Configuration" --inputbox "Enter your Git username:" 10 60 "$default_username" 3>&1 1>&2 2>&3); then
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
  if ! git_email=$(whip --title "Git Configuration" --inputbox "Enter your Git email:" 10 60 "$default_email" 3>&1 1>&2 2>&3); then
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
      whip --title "WSL Setup Failed" --msgbox "$output" 20 80
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

  if whip --title "Locale Setup" --yesno "Configure UTF-8 locale?\n\nStarship and other tools require UTF-8 locale support.\n\nThis will:\n- Check if UTF-8 locale is available\n- Let you select a UTF-8 locale if needed\n- Set system locale to UTF-8\n\nSupports Arch, Debian/Ubuntu, and RHEL-based systems." 18 70; then
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
      whip --title "Locale Setup" --msgbox "$output\n\nYou may need to log out and back in for changes to take effect.\nOr run: export LANG=en_US.UTF-8" 20 80
    else
      whip --title "Locale Setup Failed" --msgbox "$output" 20 80
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

  # Check if running as root (not via sudo, but actual root user)
  local actual_user="${SUDO_USER:-$USER}"
  local is_root=false
  if [[ "$actual_user" == "root" ]] || [[ $EUID -eq 0 && -z "${SUDO_USER:-}" ]]; then
    is_root=true
  fi

  # Dynamically include options based on available scripts and distro
  options+=("packages" "Install Packages" OFF)
  if is_arch; then
    if [[ "$is_root" == true ]]; then
      options+=("aur_setup" "Install AUR Helper (yay) [Not available for root]" OFF)
    else
      options+=("aur_setup" "Install AUR Helper (yay) [Arch]" OFF)
    fi
  fi

  options+=("locale_setup" "Configure UTF-8 Locale (for Starship)" OFF)
  options+=("git_config" "Configure Git User Settings" OFF)
  options+=("claude_statusline" "Install Claude Code statusline" OFF)

  # User creation and passwordless sudo - only show if running as root
  if [[ $EUID -eq 0 ]]; then
    # Check if user creation commands are available
    local user_creation_available="${DF_USER_CREATION_AVAILABLE:-}"
    if [[ "$user_creation_available" != "true" ]]; then
      # Environment variable not set or false, check commands directly
      if command_exists useradd && command_exists usermod && command_exists visudo; then
        user_creation_available="true"
      else
        user_creation_available="false"
      fi
    fi

    if [[ "$user_creation_available" == "true" ]]; then
      options+=("create_user" "Create New User with Sudo Access" OFF)
    fi
    options+=("passwordless_sudo" "Setup Passwordless Sudo" OFF)
  fi

  if is_wsl; then
    options+=("wsl_setup" "WSL Configuration Setup" OFF)
  fi

  options+=("gui_autologin" "Configure GUI autostart (X11/Wayland)" OFF)

  if is_arch; then
    options+=("headless_gui" "Headless GUI (Xvfb/WM/VNC/Obsidian) [Arch]" OFF)
    options+=("headless_obsidian" "Headless Obsidian (Xvfb/Openbox/VNC) [Arch]" OFF)
  fi
  if is_debian_like; then
    options+=("headless_obsidian" "Headless Obsidian (Xvfb/Openbox/VNC) [Debian/Ubuntu]" OFF)
  fi

  options+=("validate" "Validate Environment" OFF)

  if [[ ${#options[@]} -eq 0 ]]; then
    whip --title "Dotfiles Bootstrap" --msgbox "No interactive components available for this distro." 10 70
    exit 0
  fi

  local selections=""
  local selection_array=()
  if command_exists dialog; then
    local art_file tmpfile art_height art_width menu_height menu_width menu_list_height menu_col
    local art_path
    if [[ -r "$DOTFILES_DIR/assets/pixellated_bw.txt" ]]; then
      art_path="$DOTFILES_DIR/assets/pixellated_bw.txt"
    else
      art_path="$DOTFILES_DIR/assets/pixellated_plain.txt"
    fi
    tmpfile=$(mktemp)
    CLEANUP_FILES+=("$tmpfile")

    if [[ -r "$art_path" ]]; then
      art_file="$art_path"
    else
      art_file=$(mktemp)
      CLEANUP_FILES+=("$art_file")
      cat >"$art_file" <<'EOF'
      __
     |__|
     |  |
   __|  |__
  /  |  |  \
  |  |  |  |
  |  |  |  |
  |  |__|  |
  |   __   |
  |  /  \  |
  |  \__/  |
  |   /\   |
  |  /  \  |
  |_/____\_|
     ||||
     ||||
     ||||
     ||||
EOF
    fi

    local use_art=true
    local art_content_height art_content_width
    local awk_locale="C"
    if locale -a 2>/dev/null | grep -qx "C.UTF-8"; then
      awk_locale="C.UTF-8"
    elif locale -a 2>/dev/null | grep -qx "C.utf8"; then
      awk_locale="C.utf8"
    fi
    art_content_height=$(wc -l < "$art_file" | tr -d ' ')
    art_content_width=$(LC_ALL="$awk_locale" awk '{ if (length > max) max = length } END { print max }' "$art_file")

    local term_cols term_lines max_menu_height
    term_cols=$(tput cols 2>/dev/null || stty size 2>/dev/null | awk '{print $2}' || echo 80)
    term_lines=$(tput lines 2>/dev/null || stty size 2>/dev/null | awk '{print $1}' || echo 24)

    menu_height=$((term_lines - 2))
    if ((menu_height < 10)); then
      menu_height=10
    fi

    art_height=$menu_height
    art_width=$((term_cols / 3))
    if ((art_width < 20)); then
      art_width=20
    fi
    if ((art_width > term_cols - 4)); then
      art_width=$((term_cols - 4))
    fi

    local art_render_width art_render_height art_render_file
    art_render_width=$((art_width - 2))
    art_render_height=$((art_height - 2))
    if ((art_render_width < 1)); then
      art_render_width=1
    fi
    if ((art_render_height < 1)); then
      art_render_height=1
    fi

    art_render_file=$(mktemp)
    CLEANUP_FILES+=("$art_render_file")
    local errexit_was_set=0
    case $- in *e*) errexit_was_set=1 ;; esac
    set +e
    if command -v python3 >/dev/null 2>&1; then
      python3 - "$art_file" "$art_render_width" "$art_render_height" > "$art_render_file" <<'PY'
import re
import sys

path = sys.argv[1]
target_w = int(sys.argv[2])
target_h = int(sys.argv[3])

with open(path, "r", encoding="utf-8", errors="replace") as fh:
    text = fh.read()
text = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", text)
lines = [line.rstrip("\n") for line in text.splitlines()]

if not lines:
    for _ in range(target_h):
        print(" " * target_w)
    raise SystemExit(0)

src_h = len(lines)
src_w = max(len(line) for line in lines)
lines = [line.ljust(src_w) for line in lines]

def downsample(lines, target_w, target_h):
    out = []
    for y in range(target_h):
        sy = int(y * src_h / target_h)
        row = []
        for x in range(target_w):
            sx = int(x * src_w / target_w)
            row.append(lines[sy][sx])
        out.append("".join(row))
    return out

def upscale(lines, target_w, target_h):
    scale_x = max(1, target_w // src_w)
    scale_y = max(1, target_h // src_h)
    expanded = []
    for line in lines:
        expanded_line = "".join(ch * scale_x for ch in line)
        for _ in range(scale_y):
            expanded.append(expanded_line)

    # Center-crop/pad height
    if len(expanded) > target_h:
        start = (len(expanded) - target_h) // 2
        expanded = expanded[start:start + target_h]
    elif len(expanded) < target_h:
        pad_top = (target_h - len(expanded)) // 2
        pad_bottom = target_h - len(expanded) - pad_top
        expanded = ([" " * len(expanded[0])] * pad_top) + expanded + ([" " * len(expanded[0])] * pad_bottom)

    # Center-crop/pad width
    out = []
    for line in expanded:
        if len(line) > target_w:
            start = (len(line) - target_w) // 2
            line = line[start:start + target_w]
        elif len(line) < target_w:
            pad_left = (target_w - len(line)) // 2
            pad_right = target_w - len(line) - pad_left
            line = (" " * pad_left) + line + (" " * pad_right)
        out.append(line)
    return out

if target_w < src_w or target_h < src_h:
    output = downsample(lines, target_w, target_h)
else:
    output = upscale(lines, target_w, target_h)

for line in output:
    print(line)
PY
    elif command -v python >/dev/null 2>&1; then
      python - "$art_file" "$art_render_width" "$art_render_height" > "$art_render_file" <<'PY'
import re
import sys

path = sys.argv[1]
target_w = int(sys.argv[2])
target_h = int(sys.argv[3])

with open(path, "r", encoding="utf-8", errors="replace") as fh:
    text = fh.read()
text = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", text)
lines = [line.rstrip("\n") for line in text.splitlines()]

if not lines:
    for _ in range(target_h):
        print(" " * target_w)
    raise SystemExit(0)

src_h = len(lines)
src_w = max(len(line) for line in lines)
lines = [line.ljust(src_w) for line in lines]

def downsample(lines, target_w, target_h):
    out = []
    for y in range(target_h):
        sy = int(y * src_h / target_h)
        row = []
        for x in range(target_w):
            sx = int(x * src_w / target_w)
            row.append(lines[sy][sx])
        out.append("".join(row))
    return out

def upscale(lines, target_w, target_h):
    scale_x = max(1, target_w // src_w)
    scale_y = max(1, target_h // src_h)
    expanded = []
    for line in lines:
        expanded_line = "".join(ch * scale_x for ch in line)
        for _ in range(scale_y):
            expanded.append(expanded_line)

    # Center-crop/pad height
    if len(expanded) > target_h:
        start = (len(expanded) - target_h) // 2
        expanded = expanded[start:start + target_h]
    elif len(expanded) < target_h:
        pad_top = (target_h - len(expanded)) // 2
        pad_bottom = target_h - len(expanded) - pad_top
        expanded = ([" " * len(expanded[0])] * pad_top) + expanded + ([" " * len(expanded[0])] * pad_bottom)

    # Center-crop/pad width
    out = []
    for line in expanded:
        if len(line) > target_w:
            start = (len(line) - target_w) // 2
            line = line[start:start + target_w]
        elif len(line) < target_w:
            pad_left = (target_w - len(line)) // 2
            pad_right = target_w - len(line) - pad_left
            line = (" " * pad_left) + line + (" " * pad_right)
        out.append(line)
    return out

if target_w < src_w or target_h < src_h:
    output = downsample(lines, target_w, target_h)
else:
    output = upscale(lines, target_w, target_h)

for line in output:
    print(line)
PY
    else
      awk -v width="$art_render_width" -v target="$art_render_height" '
        {
          lines[++n] = $0
        }
        END {
          if (target < 1) target = n
          if (n > target) {
            start = int((n - target) / 2) + 1
            end = start + target - 1
          } else {
            start = 1
            end = n
          }
          shown = end - start + 1
          if (shown < target) {
            pad_top = int((target - shown) / 2)
            pad_bottom = target - shown - pad_top
          } else {
            pad_top = 0
            pad_bottom = 0
          }
          for (i = 0; i < pad_top; i++) {
            printf "%-*s\n", width, ""
          }
          for (i = start; i <= end; i++) {
            line = substr(lines[i], 1, width)
            printf "%-*s\n", width, line
          }
          for (i = 0; i < pad_bottom; i++) {
            printf "%-*s\n", width, ""
          }
        }
      ' "$art_file" > "$art_render_file"
    fi
    local art_rc=$?
    if ((errexit_was_set)); then
      set -e
    fi
    if ((art_rc != 0)) || [[ ! -s "$art_render_file" ]]; then
      use_art=false
    fi

    menu_col=$((art_width + 2))
    menu_width=$((term_cols - menu_col - 2))
    if ((menu_width < 40)); then
      menu_width=$((term_cols - menu_col - 2))
      if ((menu_width < 20)); then
        menu_width=20
      fi
    fi

    menu_list_height=$((menu_height - 8))
    if ((menu_list_height < 5)); then
      menu_list_height=5
    fi

    local dialog_rc=0
    if [[ "$use_art" == true ]]; then
      local art_text
      art_text=$(printf '\\Zr%s\\Zn' "$(cat "$art_render_file")")
      if PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH" dialog --backtitle "Dotfiles Bootstrap" --no-collapse --colors \
        --begin 0 0 --no-shadow --infobox "$art_text" "$art_height" "$art_width" \
        --and-widget --begin 0 "$menu_col" --checklist "Select components to configure" \
        "$menu_height" "$menu_width" "$menu_list_height" \
        "${options[@]}" 2> "$tmpfile"; then
        dialog_rc=0
      else
        dialog_rc=$?
      fi

      if [[ $dialog_rc -eq 255 && -n "${DIALOGRC:-}" && "$DIALOGRC" != "/dev/null" ]]; then
        export DIALOGRC="/dev/null"
        if PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH" dialog --backtitle "Dotfiles Bootstrap" --no-collapse --colors \
          --begin 0 0 --no-shadow --infobox "$art_text" "$art_height" "$art_width" \
          --and-widget --begin 0 "$menu_col" --checklist "Select components to configure" \
          "$menu_height" "$menu_width" "$menu_list_height" \
          "${options[@]}" 2> "$tmpfile"; then
          dialog_rc=0
        else
          dialog_rc=$?
        fi
      fi
    else
      if PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH" dialog --backtitle "Dotfiles Bootstrap" --no-collapse --colors \
        --checklist "Select components to configure" 20 80 10 \
        "${options[@]}" 2> "$tmpfile"; then
        dialog_rc=0
      else
        dialog_rc=$?
      fi

      if [[ $dialog_rc -eq 255 && -n "${DIALOGRC:-}" && "$DIALOGRC" != "/dev/null" ]]; then
        export DIALOGRC="/dev/null"
        if PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH" dialog --backtitle "Dotfiles Bootstrap" --no-collapse --colors \
          --checklist "Select components to configure" 20 80 10 \
          "${options[@]}" 2> "$tmpfile"; then
          dialog_rc=0
        else
          dialog_rc=$?
        fi
      fi
    fi
    if [[ $dialog_rc -eq 0 ]]; then
      selections=$(cat "$tmpfile")
    else
      if command_exists whiptail; then
        selections=$(whip --title "Dotfiles Bootstrap" --checklist "Select components to configure" 20 80 10 \
          "${options[@]}" \
          3>&1 1>&2 2>&3) || return 0
      else
        echo "Dotfiles Bootstrap (no TUI available)"
        echo "Select components by number (space-separated), or press Enter to quit:"
        local keys=()
        local idx=1
        for ((i=0; i<${#options[@]}; i+=3)); do
          keys+=("${options[i]}")
          printf '  [%d] %s\n' "$idx" "${options[i+1]}"
          ((idx++))
        done
        local reply
        read -r -p "> " reply || return 0
        if [[ -z "$reply" ]]; then
          return 0
        fi
        for token in $reply; do
          if [[ "$token" =~ ^[0-9]+$ ]] && (( token>=1 && token<=${#keys[@]} )); then
            selection_array+=("${keys[token-1]}")
          fi
        done
        if [[ ${#selection_array[@]} -eq 0 ]]; then
          return 0
        fi
      fi
    fi
  else
    if command_exists whiptail; then
      selections=$(whip --title "Dotfiles Bootstrap" --checklist "Select components to configure" 20 80 10 \
        "${options[@]}" \
        3>&1 1>&2 2>&3) || return 0
    else
      echo "Dotfiles Bootstrap (no TUI available)"
      echo "Select components by number (space-separated), or press Enter to quit:"
      local keys=()
      local idx=1
      for ((i=0; i<${#options[@]}; i+=3)); do
        keys+=("${options[i]}")
        printf '  [%d] %s\n' "$idx" "${options[i+1]}"
        ((idx++))
      done
      local reply
      read -r -p "> " reply || return 0
      if [[ -z "$reply" ]]; then
        return 0
      fi
      for token in $reply; do
        if [[ "$token" =~ ^[0-9]+$ ]] && (( token>=1 && token<=${#keys[@]} )); then
          selection_array+=("${keys[token-1]}")
        fi
      done
      if [[ ${#selection_array[@]} -eq 0 ]]; then
        return 0
      fi
    fi
  fi

  # Parse whiptail/dialog output into array
  if [[ ${#selection_array[@]} -eq 0 ]]; then
    eval "selection_array=($selections)"
  fi

  # Process each selection
  for sel in "${selection_array[@]}"; do
    case "$sel" in
      git_config)
        prompt_git_config || true ;;
      locale_setup)
        prompt_locale_setup || true ;;
      claude_statusline)
        prompt_claude_statusline || true ;;
      create_user)
        prompt_create_user || true ;;
      passwordless_sudo)
        prompt_passwordless_sudo || true ;;
      aur_setup)
        prompt_aur_setup || true ;;
      packages)
        prompt_packages || true ;;
      gui_autologin)
        prompt_gui_autologin || true ;;
      validate)
        prompt_validate || true ;;
      wsl_setup)
        prompt_wsl_setup || true ;;
      headless_gui)
        prompt_headless_gui || true ;;
      headless_obsidian)
        prompt_headless_obsidian || true ;;
    esac
  done

  whip --title "Dotfiles Bootstrap" --msgbox "Completed selected setup steps." 10 60 || true
}

ensure_tui
main_menu
