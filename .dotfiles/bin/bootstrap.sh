#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]] || [[ "${BOOTSTRAP_DRYRUN:-}" == "1" ]]; then
  DRY_RUN=true
fi

OS_ID=""
OS_ID_LIKE=""
OS_PRETTY=""
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"
  OS_ID_LIKE="${ID_LIKE:-}"
  OS_PRETTY="${PRETTY_NAME:-}"
fi

detect_env() {
  if [[ -d /etc/pve ]] || echo "$OS_PRETTY" | grep -qi proxmox; then
    echo "proxmox"
    return
  fi
  case "$OS_ID" in
    arch) echo "arch" ;;
    debian|ubuntu) echo "debian" ;;
    *) if [[ "${OS_ID_LIKE}" == *debian* ]]; then echo "debian"; else echo ""; fi ;;
  esac
}

ENVIRONMENT="$(detect_env)"
if [[ -z "$ENVIRONMENT" ]]; then
  echo "Unsupported OS. ID=$OS_ID ID_LIKE=$OS_ID_LIKE"
  exit 1
fi

CROSTINI=false
if [[ -d /mnt/chromeos ]]; then
  CROSTINI=true
fi

PKGLIST="$ROOT_DIR/.dotfiles/pkglists/${ENVIRONMENT}-cli.txt"
if [[ ! -f "$PKGLIST" ]]; then
  echo "Package list not found: $PKGLIST"
  exit 1
fi

install_arch() {
  local SUDO=""
  if command -v sudo >/dev/null 2>&1 && [[ "$(id -u)" -ne 0 ]]; then SUDO="sudo"; fi
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] pacman -Syu --noconfirm"
  else
    $SUDO pacman -Syu --noconfirm
  fi
  mapfile -t packages < <(grep -vE '^(#|\s*$)' "$PKGLIST")
  if [[ ${#packages[@]} -gt 0 ]]; then
    if [[ "$CROSTINI" == true ]]; then
      packages+=(wl-clipboard pinentry nss-mdns ca-certificates zip unzip xz neovim)
    fi
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] pacman -S --needed --noconfirm ${packages[*]}"
    else
      $SUDO pacman -S --needed --noconfirm "${packages[@]}"
    fi
  fi
}

install_debian() {
  export DEBIAN_FRONTEND=noninteractive
  local SUDO=""
  if command -v sudo >/dev/null 2>&1 && [[ "$(id -u)" -ne 0 ]]; then SUDO="sudo"; fi
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] apt-get update -y"
  else
    $SUDO apt-get update -y
  fi
  mapfile -t packages < <(grep -vE '^(#|\s*$)' "$PKGLIST")
  if [[ ${#packages[@]} -gt 0 ]]; then
    if [[ "$CROSTINI" == true ]]; then
      packages+=(wl-clipboard pinentry-curses libnss-mdns ca-certificates zip unzip xz-utils neovim)
    fi
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] apt-get install -y --no-install-recommends ${packages[*]}"
    else
      $SUDO apt-get install -y --no-install-recommends "${packages[@]}"
    fi
  fi
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] apt-get autoremove -y"
    echo "[DRY-RUN] apt-get clean"
  else
    $SUDO apt-get autoremove -y
    $SUDO apt-get clean
  fi
}

if [[ "$ENVIRONMENT" == "arch" ]]; then
  install_arch
else
  install_debian
fi

if [[ "$DRY_RUN" == true ]]; then
  echo "Dry-run complete for $ENVIRONMENT. No changes were made."
else
  echo "Bootstrap complete for $ENVIRONMENT."
fi