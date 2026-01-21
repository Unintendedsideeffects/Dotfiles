#!/usr/bin/env bash
set -euo pipefail

# Dotfiles bootstrap (interactive)
# Minimal-deps TUI with safe fallbacks for unprovisioned systems.

export NEWT_COLORS='root=white,black;border=white,black;window=white,black;shadow=white,black;title=white,black;button=black,white;actbutton=white,black;checkbox=white,black;actcheckbox=black,white;entry=white,black;label=white,black;listbox=white,black;actlistbox=black,white;textbox=white,black;helpline=white,black;roottext=white,black'

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$DOTFILES_DIR/bin"
LIB_DIR="$DOTFILES_DIR/lib"

# shellcheck disable=SC1090
source "$LIB_DIR/detect.sh"

for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    echo "Dry-run: bootstrap would launch the interactive setup UI."
    exit 0
  fi
done

# Track temp files for cleanup
CLEANUP_FILES=()

cleanup_handler() {
  local exit_code=$?
  for file in "${CLEANUP_FILES[@]}"; do
    [[ -f "$file" ]] && rm -f "$file"
  done
  exit "$exit_code"
}
trap cleanup_handler EXIT INT TERM

# --- Distro detection wrappers ---
is_arch() { df_is_arch; }

is_debian_like() { df_is_debian_like; }

is_rhel_like() { df_is_rhel_like; }

is_wsl() { df_is_wsl; }

# --- Helpers ---
command_exists() {
  PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH" command -v "$1" >/dev/null 2>&1
}

run_with_sudo_if_needed() {
  if [[ $EUID -ne 0 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

ensure_tui() {
  if command_exists dialog || command_exists whiptail; then
    return 0
  fi

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
  local rc=0
  local errexit_was_set=0
  case $- in *e*) errexit_was_set=1 ;; esac
  set +e

  if command_exists whiptail; then
    whiptail "$@"
    rc=$?
  else
    dialog "$@"
    rc=$?
  fi

  if ((errexit_was_set)); then
    set -e
  fi

  return "$rc"
}

# --- Menu actions ---
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

  if [[ $EUID -eq 0 && -z "${SUDO_USER:-}" ]]; then
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

  "$script"
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

  local tmpfile
  tmpfile=$(mktemp)
  CLEANUP_FILES+=("$tmpfile")
  : >"$tmpfile"

  bash "$script" --skip-preflight "$(df_package_family 2>/dev/null || true)" 2>&1 | tee "$tmpfile"
  local status=${PIPESTATUS[0]}

  if [[ $status -eq 0 ]]; then
    whip --title "Package Installation" --msgbox "Package installation completed.\n\nLog file:\n$tmpfile" 12 70
  else
    local output
    output=$(tail -n 200 "$tmpfile" 2>/dev/null || true)
    whip --title "Package Installation Failed" --msgbox "${output:-Package installation failed. Log file:\n$tmpfile}" 20 80
  fi
}

prompt_validate() {
  local script="$BIN_DIR/validate.sh"
  if [[ ! -f "$script" ]]; then
    whip --title "Validate" --msgbox "Script not found: $script" 10 70
    return 1
  elif [[ ! -x "$script" ]]; then
    whip --title "Validate" --msgbox "Script not executable: $script\n\nRun: chmod +x \"$script\"" 12 70
    return 1
  fi

  local tmpfile
  tmpfile=$(mktemp)
  CLEANUP_FILES+=("$tmpfile")
  : >"$tmpfile"

  whip --title "Validate" --tailboxbg "$tmpfile" 20 70 &
  local tail_pid=$!

  local status=0
  {
    "$script" 2>&1
    echo "$?" > "${tmpfile}.status"
  } >> "$tmpfile" || true

  status=$(cat "${tmpfile}.status" 2>/dev/null || echo "1")
  rm -f "${tmpfile}.status"

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

prompt_git_config() {
  local default_username="${GIT_USER_NAME:-$(git config --global user.name 2>/dev/null || echo "") }"
  local default_email="${GIT_USER_EMAIL:-$(git config --global user.email 2>/dev/null || echo "") }"

  if [[ -f "$HOME/.gitconfig.local" ]]; then
    local existing_name
    local existing_email
    existing_name=$(git config --file "$HOME/.gitconfig.local" user.name 2>/dev/null || echo "")
    existing_email=$(git config --file "$HOME/.gitconfig.local" user.email 2>/dev/null || echo "")
    [[ -n "$existing_name" ]] && default_username="$existing_name"
    [[ -n "$existing_email" ]] && default_email="$existing_email"
  fi

  local git_username
  if ! git_username=$(whip --title "Git Configuration" --inputbox "Enter your Git username:" 10 60 "$default_username" 3>&1 1>&2 2>&3); then
    whip --title "Git Configuration" --msgbox "Git configuration cancelled." 10 60
    return 1
  fi

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

  git_email="${git_email#"${git_email%%[![:space:]]*}"}"
  git_email="${git_email%"${git_email##*[![:space:]]}"}"

  if [[ -z "$git_email" ]]; then
    whip --title "Git Configuration" --msgbox "Git email cannot be empty." 10 60
    return 1
  fi

  if ! whip --title "Git Configuration" --yesno "Save the following configuration?\n\nName: $git_username\nEmail: $git_email" 12 70; then
    return 0
  fi

  cat > "$HOME/.gitconfig.local" <<EOF
# Local Git Configuration
# This file was automatically created during dotfiles setup
# Edit this file to update your git user information

[user]
	name = $git_username
	email = $git_email
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

    local status=0
    {
      "$script" setup 2>&1
      echo "$?" > "${tmpfile}.status"
    } >> "$tmpfile" || true

    status=$(cat "${tmpfile}.status" 2>/dev/null || echo "1")
    rm -f "${tmpfile}.status"

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
  fi
}

prompt_gui_autologin() {
  local script="$BIN_DIR/setup-gui-autologin.sh"
  if [[ ! -f "$script" ]]; then
    whip --title "GUI Autostart" --msgbox "Script not found: $script" 10 70
    return 1
  elif [[ ! -x "$script" ]]; then
    whip --title "GUI Autostart" --msgbox "Script not executable: $script\n\nRun: chmod +x \"$script\"" 12 70
    return 1
  fi

  if whip --title "GUI Autostart" --yesno "Configure GUI autostart (X11/Wayland)?" 10 60; then
    if output=$("$script" 2>&1); then
      whip --title "GUI Autostart" --msgbox "$output" 18 70
    else
      whip --title "GUI Autostart Failed" --msgbox "$output" 20 80
    fi
  fi
}

prompt_headless_gui() {
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

  while true; do
    display_num=$(whip --title "Headless GUI" --inputbox "X display number (format :N)" 10 60 ":5" 3>&1 1>&2 2>&3) || return 1
    if [[ "$display_num" =~ ^:[0-9]+$ ]]; then
      break
    else
      whip --title "Invalid Input" --msgbox "Display number must be in format :N where N is a number (e.g., :5)" 10 60
    fi
  done

  while true; do
    vnc_port=$(whip --title "Headless GUI" --inputbox "VNC port" 10 60 "5900" 3>&1 1>&2 2>&3) || return 1
    if [[ "$vnc_port" =~ ^[0-9]+$ ]] && ((vnc_port >= 1 && vnc_port <= 65535)); then
      break
    else
      whip --title "Invalid Input" --msgbox "VNC port must be a number between 1 and 65535" 10 60
    fi
  done

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

# --- UI helpers ---
setup_dialog_theme() {
  local dialogrc
  dialogrc=$(mktemp)
  CLEANUP_FILES+=("$dialogrc")
  cat >"$dialogrc" <<'EODIALOG'
use_shadow = OFF
use_colors = OFF
EODIALOG
  export DIALOGRC="$dialogrc"
}

render_art() {
  local width="$1"
  local height="$2"
  local art_file="$DOTFILES_DIR/assets/ascii-art.txt"
  local art_render
  local src_file

  art_render=$(mktemp)
  CLEANUP_FILES+=("$art_render")

  if [[ -r "$art_file" ]]; then
    src_file="$art_file"
  else
    src_file=$(mktemp)
    CLEANUP_FILES+=("$src_file")
    cat >"$src_file" <<'EOF'
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

  LC_ALL=C awk -v w="$width" -v h="$height" '
    {
      gsub(/\r$/, "", $0)
      lines[++n] = $0
    }
    END {
      if (n == 0) {
        for (i = 0; i < h; i++) printf "%*s\n", w, ""
        exit
      }

      start = 1
      if (n > h) {
        start = int((n - h) / 2) + 1
        end = start + h - 1
      } else {
        end = n
      }

      pad_top = 0
      pad_bottom = 0
      if (n < h) {
        pad_top = int((h - n) / 2)
        pad_bottom = h - n - pad_top
      }

      for (i = 0; i < pad_top; i++) printf "%*s\n", w, ""

      for (i = start; i <= end; i++) {
        line = lines[i]
        if (length(line) > w) {
          left = int((length(line) - w) / 2) + 1
          line = substr(line, left, w)
        } else if (length(line) < w) {
          pad_left = int((w - length(line)) / 2)
          pad_right = w - length(line) - pad_left
          line = sprintf("%*s%s%*s", pad_left, "", line, pad_right, "")
        }
        if (length(line) < w) line = sprintf("%-*s", w, line)
        print line
      }

      for (i = 0; i < pad_bottom; i++) printf "%*s\n", w, ""
    }
  ' "$src_file" >"$art_render"

  if [[ ! -s "$art_render" ]]; then
    printf "%*s\n" "$width" "" >"$art_render"
  fi

  cat "$art_render"
}

run_dialog_menu() {
  local tmpfile="$1"
  shift 1
  local options=("$@")

  local term_cols term_lines menu_height menu_width menu_list_height menu_col
  local art_width
  term_cols=$(tput cols 2>/dev/null || stty size 2>/dev/null | awk '{print $2}' || echo 80)
  term_lines=$(tput lines 2>/dev/null || stty size 2>/dev/null | awk '{print $1}' || echo 24)

  menu_height=$((term_lines - 2))
  if ((menu_height < 10)); then
    menu_height=10
  fi

  local art_min=20
  local menu_min=40
  local natural_width
  if [[ -r "$DOTFILES_DIR/assets/ascii-art.txt" ]]; then
    natural_width=$(LC_ALL=C awk '{ if (length > max) max = length } END { print max }' "$DOTFILES_DIR/assets/ascii-art.txt")
  else
    natural_width=$art_min
  fi
  if [[ -z "$natural_width" ]]; then
    natural_width=$art_min
  fi

  local max_art=$((term_cols - menu_min - 4))
  if ((max_art < art_min)); then
    max_art=$art_min
  fi
  art_width=$natural_width
  if ((art_width > max_art)); then
    art_width=$max_art
  fi
  if ((art_width < art_min)); then
    art_width=$art_min
  fi

  menu_col=$((art_width + 2))
  menu_width=$((term_cols - menu_col - 2))
  if ((menu_width < menu_min)); then
    menu_width=$menu_min
    menu_col=$((term_cols - menu_width - 2))
    if ((menu_col < art_min)); then
      menu_col=$((art_min + 2))
      menu_width=$((term_cols - menu_col - 2))
    fi
  fi

  menu_list_height=$((menu_height - 8))
  if ((menu_list_height < 5)); then
    menu_list_height=5
  fi

  local art_text
  art_text=$(render_art "$art_width" "$menu_height")

  if [[ -r /dev/tty && -w /dev/tty ]]; then
    dialog --backtitle "Dotfiles Bootstrap" --no-collapse --output-fd 3 \
      --begin 0 0 --no-shadow --infobox "$art_text" "$menu_height" "$art_width" \
      --and-widget --begin 0 "$menu_col" --checklist "Select components to configure" \
      "$menu_height" "$menu_width" "$menu_list_height" \
      "${options[@]}" 3>"$tmpfile" < /dev/tty > /dev/tty
  else
    dialog --backtitle "Dotfiles Bootstrap" --no-collapse --output-fd 3 \
      --begin 0 0 --no-shadow --infobox "$art_text" "$menu_height" "$art_width" \
      --and-widget --begin 0 "$menu_col" --checklist "Select components to configure" \
      "$menu_height" "$menu_width" "$menu_list_height" \
      "${options[@]}" 3>"$tmpfile"
  fi
}

run_plain_menu() {
  local options=("$@")
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
  if [[ -r /dev/tty ]]; then
    read -r -p "> " reply < /dev/tty || return 1
  else
    read -r -p "> " reply || return 1
  fi

  if [[ -z "$reply" ]]; then
    return 1
  fi

  local selection_array=()
  for token in $reply; do
    if [[ "$token" =~ ^[0-9]+$ ]] && (( token>=1 && token<=${#keys[@]} )); then
      selection_array+=("${keys[token-1]}")
    fi
  done

  if [[ ${#selection_array[@]} -eq 0 ]]; then
    return 1
  fi

  printf '%s\n' "${selection_array[@]}"
}

main_menu() {
  local options=()

  options+=("packages" "Install Packages" OFF)
  if is_arch; then
    options+=("aur_setup" "Install AUR Helper (yay) [Arch]" OFF)
  fi

  options+=("locale_setup" "Configure UTF-8 Locale (for Starship)" OFF)
  options+=("git_config" "Configure Git User Settings" OFF)
  options+=("claude_statusline" "Install Claude Code statusline" OFF)

  if is_wsl; then
    options+=("wsl_setup" "WSL Configuration Setup" OFF)
  fi

  options+=("gui_autologin" "Configure GUI autostart (X11/Wayland)" OFF)

  if is_arch; then
    options+=("headless_gui" "Headless GUI (Xvfb/WM/VNC/Obsidian) [Arch]" OFF)
    options+=("headless_obsidian" "Headless Obsidian (Xvfb/Openbox/VNC) [Arch]" OFF)
  fi

  options+=("validate" "Validate Environment" OFF)

  if [[ ${#options[@]} -eq 0 ]]; then
    whip --title "Dotfiles Bootstrap" --msgbox "No interactive components available for this distro." 10 70
    exit 0
  fi

  local selections=""
  if command_exists dialog; then
    setup_dialog_theme
    local tmpfile
    tmpfile=$(mktemp)
    CLEANUP_FILES+=("$tmpfile")

    run_dialog_menu "$tmpfile" "${options[@]}" || true
    local dialog_rc=$?

    if [[ $dialog_rc -eq 0 ]]; then
      selections=$(cat "$tmpfile")
    elif [[ $dialog_rc -eq 1 || $dialog_rc -eq 255 ]]; then
      return 0
    else
      selections=""
    fi
  elif command_exists whiptail; then
    selections=$(whip --title "Dotfiles Bootstrap" --checklist "Select components to configure" 20 80 10 \
      "${options[@]}" \
      3>&1 1>&2 2>&3) || return 0
  else
    selections=$(run_plain_menu "${options[@]}") || return 0
  fi

  if [[ -z "$selections" ]]; then
    return 0
  fi

  local selection_array=()
  eval "selection_array=($selections)"

  for sel in "${selection_array[@]}"; do
    case "$sel" in
      git_config) prompt_git_config || true ;;
      locale_setup) prompt_locale_setup || true ;;
      claude_statusline) prompt_claude_statusline || true ;;
      aur_setup) prompt_aur_setup || true ;;
      packages) prompt_packages || true ;;
      gui_autologin) prompt_gui_autologin || true ;;
      validate) prompt_validate || true ;;
      wsl_setup) prompt_wsl_setup || true ;;
      headless_gui) prompt_headless_gui || true ;;
      headless_obsidian) prompt_headless_obsidian || true ;;
    esac
  done

  whip --title "Dotfiles Bootstrap" --msgbox "Completed selected setup steps." 10 60 || true
}

ensure_tui
main_menu
