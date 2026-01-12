#!/usr/bin/env bash
set -euo pipefail

# Locale detection and setup for Starship and other UTF-8 dependent tools
# Supports Arch, Debian-based, and RHEL-based distributions

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$DOTFILES_DIR/lib"

# shellcheck disable=SC1090
source "$LIB_DIR/detect.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# Check if running with sudo when needed
run_with_sudo_if_needed() {
  if [[ $EUID -ne 0 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

# Detect if UTF-8 locale is available
check_utf8_locale() {
  # Check if any UTF-8 locale is available
  if locale -a 2>/dev/null | grep -qi "utf"; then
    return 0
  fi
  return 1
}

# Check current locale setting
check_current_locale() {
  local current_lang="${LANG:-}"
  local current_lc_all="${LC_ALL:-}"

  if [[ -z "$current_lang" ]] || [[ "$current_lang" == "C" ]] || [[ "$current_lang" == "POSIX" ]]; then
    return 1
  fi

  if [[ "$current_lang" =~ [Uu][Tt][Ff]-?8 ]]; then
    return 0
  fi

  return 1
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

  # Set system-wide locale
  log_info "Setting system locale to en_US.UTF-8..."
  run_with_sudo_if_needed sh -c "echo 'LANG=en_US.UTF-8' > $locale_conf_file"

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
