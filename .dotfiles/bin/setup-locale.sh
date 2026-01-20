#!/usr/bin/env bash
set -euo pipefail

# Locale detection and setup for Starship and other UTF-8 dependent tools
# Supports Arch, Debian-based, and RHEL-based distributions

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$DOTFILES_DIR/lib"

# shellcheck disable=SC1090
source "$LIB_DIR/detect.sh"

# Colors for output (disabled when not on a TTY or NO_COLOR is set)
USE_COLOR=true
if [[ -n "${NO_COLOR:-}" || ! -t 1 ]]; then
  USE_COLOR=false
fi

RED=''
GREEN=''
YELLOW=''
BLUE=''
NC=''
if [[ "$USE_COLOR" == true ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'
  NC=$'\033[0m'
fi

log_info() {
  printf '%s\n' "${BLUE}[INFO]${NC} $*"
}

log_success() {
  printf '%s\n' "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  printf '%s\n' "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  printf '%s\n' "${RED}[ERROR]${NC} $*"
}

# Check if running with sudo when needed
run_with_sudo_if_needed() {
  if [[ $EUID -ne 0 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

# Detect if UTF-8 locale is available (ignore C.UTF-8 false positives)
check_utf8_locale() {
  if locale -a 2>/dev/null | grep -Eqi '^[[:alpha:]]{2}_[[:alpha:]]{2}.*utf-?8'; then
    return 0
  fi
  return 1
}

# Check current locale setting
check_current_locale() {
  local current_lang="${LANG:-}"
  local current_lc_all="${LC_ALL:-}"

  if [[ -z "$current_lang" ]] || [[ "$current_lang" == "C" ]] || [[ "$current_lang" == "POSIX" ]] || [[ "$current_lang" == C.* ]]; then
    return 1
  fi

  if [[ "$current_lang" =~ [Uu][Tt][Ff]-?8 ]]; then
    return 0
  fi

  return 1
}

# --- TUI helpers (whiptail/dialog) ---
has_whiptail() { command -v whiptail >/dev/null 2>&1; }
has_dialog() { command -v dialog >/dev/null 2>&1; }

tui_inputbox() {
  local title="$1"
  local prompt="$2"
  local default="${3:-}"
  local value=""

  if has_whiptail; then
    value=$(whiptail --title "$title" --inputbox "$prompt" 10 70 "$default" 3>&1 1>&2 2>&3) || return 1
    printf '%s' "$value"
    return 0
  fi

  if has_dialog; then
    value=$(dialog --title "$title" --inputbox "$prompt" 10 70 "$default" 3>&1 1>&2 2>&3) || return 1
    printf '%s' "$value"
    return 0
  fi

  if [[ -r /dev/tty ]]; then
    IFS= read -r -p "$prompt" value </dev/tty || return 1
    printf '%s' "$value"
    return 0
  fi

  return 1
}

tui_msgbox() {
  local title="$1"
  local message="$2"

  if has_whiptail; then
    whiptail --title "$title" --msgbox "$message" 10 70
    return 0
  fi

  if has_dialog; then
    dialog --title "$title" --msgbox "$message" 10 70
    return 0
  fi

  printf '%s\n' "$message"
}

tui_checklist() {
  local title="$1"
  local prompt="$2"
  shift 2
  local selections=""

  if has_whiptail; then
    selections=$(whiptail --title "$title" --checklist "$prompt" 20 78 12 "$@" 3>&1 1>&2 2>&3) || return 1
  elif has_dialog; then
    selections=$(dialog --title "$title" --checklist "$prompt" 20 78 12 "$@" 3>&1 1>&2 2>&3) || return 1
  else
    return 1
  fi

  selections=${selections//\"/}
  printf '%s' "$selections"
  return 0
}

list_arch_utf8_locales() {
  local locale_gen_file="$1"
  awk '/UTF-8/ {
    line=$0
    sub(/^[[:space:]]*#?[[:space:]]*/, "", line)
    split(line, fields, /[[:space:]]+/)
    if (fields[1] ~ /^[A-Za-z]{2}_[A-Za-z]{2}.*UTF-8$/) {
      print fields[1]
    }
  }' "$locale_gen_file" | sort -u
}

select_arch_locales() {
  local locale_gen_file="$1"
  local locales prefix filtered selections

  locales=$(list_arch_utf8_locales "$locale_gen_file")
  if [[ -z "$locales" ]]; then
    log_error "No UTF-8 locales found in $locale_gen_file"
    return 1
  fi

  while true; do
    prefix=$(tui_inputbox "Locale Setup" "Enter a two-letter language code (e.g., en for English, it for Italian):" "en") || return 1
    prefix=${prefix,,}
    if [[ ! "$prefix" =~ ^[a-z]{2}$ ]]; then
      tui_msgbox "Locale Setup" "Please enter exactly two letters (e.g., en, it, fr)."
      continue
    fi

    filtered=$(printf '%s\n' "$locales" | grep -E "^${prefix}_" || true)
    if [[ -z "$filtered" ]]; then
      tui_msgbox "Locale Setup" "No UTF-8 locales found for '$prefix'. Try another two-letter code."
      continue
    fi

    local options=()
    while IFS= read -r locale; do
      options+=("$locale" "UTF-8 locale" OFF)
    done <<< "$filtered"

    selections=$(tui_checklist "Locale Setup" "Select locale(s) to enable" "${options[@]}") || return 1
    if [[ -z "$selections" ]]; then
      tui_msgbox "Locale Setup" "Select at least one locale to continue."
      continue
    fi

    local selected_array=()
    read -r -a selected_array <<< "$selections"
    printf '%s\n' "${selected_array[@]}"
    return 0
  done
}

# Generate locale on Arch Linux
setup_locale_arch() {
  log_info "Setting up locale for Arch Linux..."

  local locale_gen_file="/etc/locale.gen"
  local locale_conf_file="/etc/locale.conf"

  if [[ ! -f "$locale_gen_file" ]]; then
    log_error "locale.gen not found at $locale_gen_file"
    return 1
  fi

  local selected_locales=()
  if mapfile -t selected_locales < <(select_arch_locales "$locale_gen_file"); then
    :
  else
    log_error "Locale selection cancelled."
    return 1
  fi

  for locale in "${selected_locales[@]}"; do
    if grep -Eq "^[[:space:]]*${locale}[[:space:]]+UTF-8" "$locale_gen_file"; then
      log_info "$locale is already enabled in locale.gen"
      continue
    fi
    log_info "Adding $locale to locale.gen..."
    run_with_sudo_if_needed sh -c "printf '\n%s UTF-8\n' '$locale' >> '$locale_gen_file'"
  done

  # Generate locales
  log_info "Running locale-gen..."
  run_with_sudo_if_needed locale-gen

  # Set system-wide locale (use the first selected locale)
  local default_locale="${selected_locales[0]}"
  log_info "Setting system locale to ${default_locale}..."
  run_with_sudo_if_needed sh -c "echo 'LANG=${default_locale}' > $locale_conf_file"

  log_success "Locale configured successfully!"
}

# Generate locale on Debian/Ubuntu
setup_locale_debian() {
  log_info "Setting up locale for Debian/Ubuntu..."

  # Check if locale-gen exists
  if ! command -v locale-gen >/dev/null 2>&1; then
    log_info "Installing locales package..."
    run_with_sudo_if_needed apt-get update -y
    run_with_sudo_if_needed apt-get install -y locales
  fi

  # Debian/Ubuntu use /etc/locale.gen similarly to Arch
  local locale_gen_file="/etc/locale.gen"

  if [[ -f "$locale_gen_file" ]]; then
    # Check if en_US.UTF-8 is already uncommented
    if grep -q "^en_US\.UTF-8 UTF-8" "$locale_gen_file"; then
      log_info "en_US.UTF-8 is already enabled in locale.gen"
    else
      log_info "Enabling en_US.UTF-8 in locale.gen..."
      run_with_sudo_if_needed sed -i 's/^#\s*en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' "$locale_gen_file"

      # If that didn't work (line doesn't exist), append it
      if ! grep -q "^en_US\.UTF-8 UTF-8" "$locale_gen_file"; then
        log_info "Adding en_US.UTF-8 to locale.gen..."
        run_with_sudo_if_needed sh -c "echo 'en_US.UTF-8 UTF-8' >> $locale_gen_file"
      fi
    fi

    # Generate locales
    log_info "Running locale-gen..."
    run_with_sudo_if_needed locale-gen
  else
    # Alternative method using dpkg-reconfigure
    log_info "Generating en_US.UTF-8 locale using locale-gen..."
    run_with_sudo_if_needed locale-gen en_US.UTF-8
  fi

  # Update locale
  log_info "Setting system locale to en_US.UTF-8..."
  run_with_sudo_if_needed update-locale LANG=en_US.UTF-8

  log_success "Locale configured successfully!"
}

# Generate locale on RHEL/Fedora/Rocky
setup_locale_rhel() {
  log_info "Setting up locale for RHEL-based system..."

  # RHEL systems use localectl
  if command -v localectl >/dev/null 2>&1; then
    log_info "Setting locale using localectl..."
    run_with_sudo_if_needed localectl set-locale LANG=en_US.UTF-8
    log_success "Locale configured successfully!"
  else
    log_error "localectl not found. Manual configuration required."
    return 1
  fi
}

# Main setup function
setup_locale() {
  log_info "Checking current locale configuration..."

  # Check if UTF-8 locale is already available
  if check_utf8_locale; then
    log_success "UTF-8 locale is already available on the system."

    # Check if current locale is set properly
    if check_current_locale; then
      log_success "Current locale is already set to UTF-8: $LANG"
      log_info "No action needed!"
      return 0
    else
      log_warning "UTF-8 locale is available but not set as default."
      log_info "Current LANG: ${LANG:-<not set>}"
      log_info "You may need to set LANG=en_US.UTF-8 in your environment."
    fi
  else
    log_warning "No UTF-8 locale found. This can cause issues with Starship and other tools."
    log_info "Attempting to configure locale..."

    # Determine distro and run appropriate setup
    if df_is_arch; then
      setup_locale_arch
    elif df_is_debian_like; then
      setup_locale_debian
    elif df_is_rhel_like; then
      setup_locale_rhel
    else
      log_error "Unsupported distribution. Please configure UTF-8 locale manually."
      log_info "You may need to:"
      log_info "  1. Edit /etc/locale.gen and uncomment en_US.UTF-8"
      log_info "  2. Run locale-gen"
      log_info "  3. Set LANG=en_US.UTF-8 in /etc/locale.conf or /etc/environment"
      return 1
    fi
  fi

  # Verify setup
  echo ""
  log_info "Verifying locale configuration..."
  if check_utf8_locale; then
    log_success "UTF-8 locale is now available!"
    echo ""
    echo "Available UTF-8 locales:"
    locale -a 2>/dev/null | grep -i utf || true
    echo ""
    log_info "You may need to log out and back in for changes to take effect."
    log_info "Or run: export LANG=en_US.UTF-8"
  else
    log_error "Locale setup may have failed. Please check manually."
    return 1
  fi
}

# Show current status
show_status() {
  echo "Current Locale Status:"
  echo "====================="
  echo "LANG: ${LANG:-<not set>}"
  echo "LC_ALL: ${LC_ALL:-<not set>}"
  echo "LC_CTYPE: ${LC_CTYPE:-<not set>}"
  echo ""
  echo "Available UTF-8 locales:"
  locale -a 2>/dev/null | grep -i utf || echo "  None found"
}

# Main
main() {
  case "${1:-setup}" in
    status)
      show_status
      ;;
    setup|*)
      setup_locale
      ;;
  esac
}

main "$@"
