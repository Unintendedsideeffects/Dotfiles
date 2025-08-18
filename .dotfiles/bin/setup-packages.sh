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

install_pkgs() {
  mapfile -t pkgs < <(grep -vE '^(#|\s*$)' "$PKGLIST")
  echo "Packages to install: ${#pkgs[@]}"
  
  # Determine if we need sudo
  local use_sudo=""
  if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    use_sudo="sudo"
  fi
  
  if [[ "$ENV" == "arch" ]]; then
    if [[ "$DRY" == true ]]; then
      echo "[DRY-RUN] $use_sudo pacman -S --needed --noconfirm ${pkgs[*]}"
    else
      $use_sudo pacman -S --needed --noconfirm "${pkgs[@]}"
    fi
  else
    if [[ "$DRY" == true ]]; then
      echo "[DRY-RUN] $use_sudo apt-get update -y && $use_sudo apt-get install -y ${pkgs[*]}"
    else
      $use_sudo apt-get update -y
      $use_sudo apt-get install -y "${pkgs[@]}"
    fi
  fi
}

install_pkgs
echo "Package installation completed!"