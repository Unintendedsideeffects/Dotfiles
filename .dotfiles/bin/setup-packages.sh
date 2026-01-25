#!/usr/bin/env bash
if [ -z "${BASH_VERSION:-}" ]; then
  exec /usr/bin/env bash "$0" "$@"
fi
set -euo pipefail

# Package installation script with WSL detection
# Usage: setup-packages.sh [--dry-run] [--preflight] [--skip-preflight] [package-type]
# package-type: cli, gui, xforward, wsl (auto-detected if not specified)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$ROOT_DIR/.dotfiles/lib"

# shellcheck disable=SC1090
source "$LIB_DIR/detect.sh"

DRY=false
PACKAGE_TYPE=""
PREFLIGHT=false
SKIP_PREFLIGHT=false
APT_UPDATED=false
PROXMOX_REPOS_CHANGED=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY=true
      shift
      ;;
    --preflight)
      PREFLIGHT=true
      shift
      ;;
    --skip-preflight)
      SKIP_PREFLIGHT=true
      shift
      ;;
    *)
      PACKAGE_TYPE="$1"
      shift
      ;;
  esac
done

# OS detection (via shared helper)
OS_ID="$(df_os_id)"

# Environment detection
ENV="$(df_package_family || true)"
if [[ -z "$ENV" ]]; then
  echo "Unsupported OS: ${OS_ID:-unknown}"
  exit 1
fi

if [[ "$ENV" == "rocky" && "${OS_ID:-}" == "fedora" ]]; then
  echo "WARNING: Fedora detected. Using Rocky package lists; some packages may fail to install."
fi

# WSL detection
IS_WSL=false
if df_is_wsl; then
  IS_WSL=true
fi

# Auto-detect package type if not specified
if [[ -z "$PACKAGE_TYPE" ]]; then
  if [[ "$IS_WSL" == true ]]; then
    PACKAGE_TYPE="wsl"
  else
    PACKAGE_TYPE="cli"
  fi
fi

# Normalize package type if user passed OS name by mistake.
case "$PACKAGE_TYPE" in
  cli|gui|xforward|wsl)
    ;;
  *)
    if [[ "$PACKAGE_TYPE" == "$ENV" ]]; then
      echo "WARNING: Package type '$PACKAGE_TYPE' looks like an OS name; using 'cli' package list."
      PACKAGE_TYPE="cli"
    else
      echo "Unknown package type: $PACKAGE_TYPE (valid: cli, gui, xforward, wsl)"
      exit 1
    fi
    ;;
esac

# Determine package list file
PKGLIST="$ROOT_DIR/.dotfiles/pkglists/${ENV}-${PACKAGE_TYPE}.txt"
if [[ ! -f "$PKGLIST" ]]; then 
  echo "Missing package list: $PKGLIST"
  # Fallback to CLI if WSL-specific list doesn't exist
  if [[ "$PACKAGE_TYPE" == "wsl" ]]; then
    echo "Falling back to CLI package list..."
    PKGLIST="$ROOT_DIR/.dotfiles/pkglists/${ENV}-cli.txt"
    if [[ ! -f "$PKGLIST" ]]; then
      echo "Missing fallback list: $PKGLIST"
      exit 1
    fi
  else
    exit 1
  fi
fi

echo "Installing packages for: $ENV ($PACKAGE_TYPE)"
echo "Package list: $PKGLIST"
if [[ "$IS_WSL" == true ]]; then
  echo "WSL environment detected"
fi

# Helper function to run commands with sudo when needed
run_cmd() {
  if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    "$@"
  fi
}

prompt_yes_no() {
  local prompt="$1"
  if [[ "${USE_WHIPTAIL:-}" == "1" ]]; then
    if command -v whiptail >/dev/null 2>&1; then
      whiptail --title "Proxmox Repositories" --yesno "$prompt" 12 70
      return $?
    fi
    if command -v dialog >/dev/null 2>&1; then
      dialog --title "Proxmox Repositories" --yesno "$prompt" 12 70
      return $?
    fi
  fi

  if [[ ! -r /dev/tty ]]; then
    return 2
  fi

  local reply
  read -p "$prompt (y/N): " -n 1 -r reply </dev/tty
  echo
  [[ "$reply" =~ ^[Yy]$ ]]
}

read_debian_codename() {
  local codename=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    codename="${VERSION_CODENAME:-${DEBIAN_CODENAME:-}}"
  fi
  printf '%s' "$codename"
}

ensure_proxmox_no_subscription_repo() {
  if ! df_is_proxmox; then
    return 0
  fi

  local codename repo_line repo_file
  codename="$(read_debian_codename)"
  if [[ -z "$codename" ]]; then
    echo "WARNING: Unable to determine Debian codename for Proxmox; skipping repo setup."
    return
  fi

  local pve_repo_line ceph_repo_line
  pve_repo_line="deb http://download.proxmox.com/debian/pve ${codename} pve-no-subscription"
  ceph_repo_line="deb http://download.proxmox.com/debian/ceph-squid ${codename} no-subscription"

  local needs_repo=false
  if ! grep -RqsF "$pve_repo_line" /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null; then
    needs_repo=true
  fi
  if ! grep -RqsF "$ceph_repo_line" /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null; then
    needs_repo=true
  fi

  local enterprise_files=()
  if grep -Rqs "enterprise.proxmox.com" /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null; then
    while IFS= read -r file; do
      enterprise_files+=("$file")
    done < <(grep -Rl "enterprise.proxmox.com" /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null)
  fi

  if [[ "$needs_repo" != true && ${#enterprise_files[@]} -eq 0 ]]; then
    return 0
  fi

  if [[ "$DRY" == true ]]; then
    if ((${#enterprise_files[@]})); then
      echo "[DRY-RUN] Disable Proxmox enterprise repos in: ${enterprise_files[*]}"
    fi
    if [[ "$needs_repo" == true ]]; then
      echo "[DRY-RUN] Enable Proxmox no-subscription repos:"
      echo "[DRY-RUN]   $pve_repo_line"
      echo "[DRY-RUN]   $ceph_repo_line"
    fi
    return 0
  fi

  if ((${#enterprise_files[@]})); then
    prompt_yes_no "Disable Proxmox enterprise repos (401 without subscription)?"
    local prompt_rc=$?
    if [[ $prompt_rc -eq 2 ]]; then
      echo "Proxmox detected. Repo changes needed; rerun with a TTY to update repos."
      return 1
    fi
    if [[ $prompt_rc -eq 0 ]]; then
      for file in "${enterprise_files[@]}"; do
        if [[ "$file" == *.sources ]]; then
          if grep -qi '^Enabled:\s*no' "$file"; then
            continue
          fi
          run_cmd awk '
            BEGIN { added=0 }
            /^Enabled:/ { print "Enabled: no"; added=1; next }
            { print }
            END { if (added==0) print "Enabled: no" }
          ' "$file" > "${file}.tmp"
          run_cmd mv "${file}.tmp" "$file"
        else
          run_cmd sed -i 's/^[^#]/#&/' "$file"
        fi
        echo "Disabled enterprise repo in $file"
      done
      PROXMOX_REPOS_CHANGED=true
    fi
  fi

  if [[ "$needs_repo" == true ]]; then
    prompt_yes_no "Enable Proxmox no-subscription repos?"
    local prompt_rc=$?
    if [[ $prompt_rc -eq 2 ]]; then
      echo "Proxmox detected. Repo changes needed; rerun with a TTY to update repos."
      return 1
    fi
    if [[ $prompt_rc -eq 0 ]]; then
      repo_file="/etc/apt/sources.list.d/pve-no-subscription.list"
      run_cmd mkdir -p /etc/apt/sources.list.d
      {
        printf '%s\n' "$pve_repo_line"
        printf '%s\n' "$ceph_repo_line"
      } | run_cmd tee "$repo_file" >/dev/null
      echo "Added $repo_file"
      PROXMOX_REPOS_CHANGED=true
    fi
  fi

  if [[ "$DRY" == true ]]; then
    return 0
  fi

  if ! dpkg -s proxmox-archive-keyring >/dev/null 2>&1; then
    prompt_yes_no "Install Proxmox archive keyring package?"
    local prompt_rc=$?
    if [[ $prompt_rc -eq 2 ]]; then
      echo "Proxmox keyring missing; rerun with a TTY to install proxmox-archive-keyring."
      return 1
    fi
    if [[ $prompt_rc -eq 0 ]]; then
      if [[ "$PROXMOX_REPOS_CHANGED" == true && "$APT_UPDATED" == false ]]; then
        run_cmd apt-get update -y
        APT_UPDATED=true
      fi
      run_cmd apt-get install -y proxmox-archive-keyring
      echo "Installed proxmox-archive-keyring"
    fi
  fi
  return 0
}

if [[ "$PREFLIGHT" == true ]]; then
  ensure_proxmox_no_subscription_repo
  exit $?
fi

select_rhel_pkg_manager() {
  if command -v dnf >/dev/null 2>&1; then
    echo "dnf"
    return 0
  fi
  if command -v yum >/dev/null 2>&1; then
    echo "yum"
    return 0
  fi
  return 1
}

ensure_zsh_default_shell() {
  if ! command -v zsh >/dev/null 2>&1; then
    echo "zsh not installed, skipping default shell update"
    return
  fi

  local target_user
  target_user=${SUDO_USER:-$USER}

  if [[ -z "$target_user" ]]; then
    echo "Unable to determine target user for default shell update"
    return
  fi

  local zsh_path current_shell
  zsh_path="$(command -v zsh)"
  current_shell="$(getent passwd "$target_user" | cut -d: -f7)"

  if [[ "$current_shell" == "$zsh_path" ]]; then
    echo "Default shell already set to zsh for $target_user"
    return
  fi

  echo "Setting default shell to zsh for $target_user"

  # Prefer usermod over chsh when available - chsh uses PAM which prompts
  # for password even with passwordless sudo (fails on Android Termux, etc.)
  if [[ $EUID -eq 0 ]]; then
    if command -v usermod >/dev/null 2>&1; then
      usermod -s "$zsh_path" "$target_user"
    elif command -v chsh >/dev/null 2>&1; then
      chsh -s "$zsh_path" "$target_user"
    else
      echo "Neither usermod nor chsh available, cannot change shell"
      return
    fi
  elif command -v sudo >/dev/null 2>&1; then
    if sudo -n true 2>/dev/null && command -v usermod >/dev/null 2>&1; then
      # Passwordless sudo available - use usermod to avoid PAM password prompt
      sudo usermod -s "$zsh_path" "$target_user"
    elif command -v chsh >/dev/null 2>&1 && [[ "$USER" == "$target_user" ]]; then
      # Fall back to chsh for current user (will prompt for password)
      echo "Note: chsh may prompt for your password"
      chsh -s "$zsh_path" || echo "Shell change skipped (password required)"
    else
      echo "Cannot change shell without password prompt, skipping"
    fi
  else
    echo "Insufficient permissions to change shell for $target_user"
  fi
}

install_pkgs() {
  mapfile -t pkgs < <(grep -vE '^(#|\s*$)' "$PKGLIST")
  echo "Packages to install: ${#pkgs[@]}"

  if [[ "$ENV" == "arch" ]]; then
    pacman_pkgs=()
    aur_pkgs=()

    for pkg in "${pkgs[@]}"; do
      if [[ "$pkg" == aur:* ]]; then
        aur_pkgs+=("${pkg#aur:}")
      else
        pacman_pkgs+=("$pkg")
      fi
    done

    if [[ "$DRY" == true ]]; then
      if ((${#pacman_pkgs[@]})); then
        echo "[DRY-RUN] pacman -Syy --needed --noconfirm ${pacman_pkgs[*]}"
      fi
      if ((${#aur_pkgs[@]})); then
        echo "[DRY-RUN] yay -S --needed --noconfirm ${aur_pkgs[*]}"
      fi
      return
    fi

    if ((${#pacman_pkgs[@]})); then
      echo "Refreshing package databases and mirrors..."
      run_cmd pacman -Syy --noconfirm
      echo "Installing pacman packages..."
      run_cmd pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
    fi

    if ((${#aur_pkgs[@]})); then
      if ! command -v yay >/dev/null 2>&1; then
        echo "WARNING: Skipping AUR packages (missing yay): ${aur_pkgs[*]}"
        echo "    Run setup-aur.sh to install yay, then rerun this script."
      else
        echo "Installing AUR packages with yay..."
        yay -S --needed --noconfirm "${aur_pkgs[@]}"
      fi
    fi
  elif [[ "$ENV" == "rocky" ]]; then
    local pkg_manager
    if ! pkg_manager=$(select_rhel_pkg_manager); then
      echo "No supported RHEL package manager found (dnf or yum)."
      exit 1
    fi
    if [[ "$DRY" == true ]]; then
      echo "[DRY-RUN] $pkg_manager install -y ${pkgs[*]}"
    else
      run_cmd "$pkg_manager" install -y "${pkgs[@]}"
    fi
  else
    if [[ "$SKIP_PREFLIGHT" != true ]]; then
      if ! ensure_proxmox_no_subscription_repo; then
        echo "Package installation halted until Proxmox repos are configured."
        return 1
      fi
    fi
    if [[ "$DRY" == true ]]; then
      echo "[DRY-RUN] apt-get update -y && apt-get install -y ${pkgs[*]}"
    else
      if [[ "$APT_UPDATED" == false ]]; then
        run_cmd apt-get update -y
        APT_UPDATED=true
      fi
      run_cmd apt-get install -y "${pkgs[@]}"
    fi
  fi

  ensure_zsh_default_shell
}

install_pkgs
echo "Package installation completed!"
