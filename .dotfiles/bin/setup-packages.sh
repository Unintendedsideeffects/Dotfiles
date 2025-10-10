#!/usr/bin/env bash
set -euo pipefail

# Package installation script with WSL detection
# Usage: setup-packages.sh [--dry-run] [package-type]
# package-type: cli, gui, xforward, wsl (auto-detected if not specified)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

DRY=false
PACKAGE_TYPE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY=true
      shift
      ;;
    *)
      PACKAGE_TYPE="$1"
      shift
      ;;
  esac
done

# OS detection
OS_ID=""; OS_LIKE=""; PRETTY=""
if [[ -r /etc/os-release ]]; then . /etc/os-release; OS_ID=${ID:-}; OS_LIKE=${ID_LIKE:-}; PRETTY=${PRETTY_NAME:-}; fi

# Environment detection
ENV=""
case "$OS_ID" in
  arch) ENV="arch" ;; 
  debian|ubuntu) ENV="debian"; ;;
  *) [[ "$OS_LIKE" == *debian* ]] && ENV="debian" || ENV="" ;;
esac

if [[ -z "$ENV" ]]; then echo "Unsupported OS: $OS_ID"; exit 1; fi

# WSL detection
IS_WSL=false
if [[ -f /proc/version ]] && grep -q Microsoft /proc/version; then
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

ensure_zsh_default_shell() {
  if ! command -v zsh >/dev/null 2>&1; then
    echo "zsh not installed, skipping default shell update"
    return
  fi

  if ! command -v chsh >/dev/null 2>&1; then
    echo "chsh command not found, cannot set default shell"
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

  if [[ $EUID -eq 0 ]]; then
    chsh -s "$zsh_path" "$target_user"
  elif [[ "$USER" == "$target_user" ]]; then
    chsh -s "$zsh_path"
  elif command -v sudo >/dev/null 2>&1; then
    sudo chsh -s "$zsh_path" "$target_user"
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
        echo "⚠️  Skipping AUR packages (missing yay): ${aur_pkgs[*]}"
        echo "    Run setup-aur.sh to install yay, then rerun this script."
      else
        echo "Installing AUR packages with yay..."
        yay -S --needed --noconfirm "${aur_pkgs[@]}"
      fi
    fi
  else
    if [[ "$DRY" == true ]]; then
      echo "[DRY-RUN] apt-get update -y && apt-get install -y ${pkgs[*]}"
    else
      run_cmd apt-get update -y
      run_cmd apt-get install -y "${pkgs[@]}"
    fi
  fi

  ensure_zsh_default_shell
}

install_pkgs
echo "Package installation completed!"
