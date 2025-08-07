#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

DRY=false
if [[ "${1:-}" == "--dry-run" ]]; then DRY=true; fi

OS_ID=""; OS_LIKE=""; PRETTY=""
if [[ -r /etc/os-release ]]; then . /etc/os-release; OS_ID=${ID:-}; OS_LIKE=${ID_LIKE:-}; PRETTY=${PRETTY_NAME:-}; fi

ENV=""
case "$OS_ID" in
  arch) ENV="arch" ;; 
  debian|ubuntu) ENV="debian"; ;;
  *) [[ "$OS_LIKE" == *debian* ]] && ENV="debian" || ENV="" ;;
esac

if [[ -z "$ENV" ]]; then echo "Unsupported OS"; exit 1; fi

PKGLIST="$ROOT_DIR/.dotfiles/pkglists/${ENV}-xforward.txt"
if [[ ! -f "$PKGLIST" ]]; then echo "Missing list: $PKGLIST"; exit 1; fi

install_pkgs() {
  mapfile -t pkgs < <(grep -vE '^(#|\s*$)' "$PKGLIST")
  if [[ "$ENV" == arch ]]; then
    [[ "$DRY" == true ]] && echo "[DRY-RUN] pacman -S --needed --noconfirm ${pkgs[*]}" || sudo pacman -S --needed --noconfirm "${pkgs[@]}"
  else
    [[ "$DRY" == true ]] && echo "[DRY-RUN] apt-get update -y" || sudo apt-get update -y
    [[ "$DRY" == true ]] && echo "[DRY-RUN] apt-get install -y --no-install-recommends ${pkgs[*]}" || sudo apt-get install -y --no-install-recommends "${pkgs[@]}"
  fi
}

configure_sshd() {
  local sshd_conf=/etc/ssh/sshd_config
  local lines=(
    "X11Forwarding yes"
    "X11UseLocalhost no"
    "AllowTcpForwarding yes"
  )
  if [[ "$DRY" == true ]]; then
    echo "[DRY-RUN] ensure in $sshd_conf: ${lines[*]}"
  else
    sudo sed -i 's/^#\?X11Forwarding.*/X11Forwarding yes/' "$sshd_conf" || true
    sudo sed -i 's/^#\?X11UseLocalhost.*/X11UseLocalhost no/' "$sshd_conf" || true
    sudo sed -i 's/^#\?AllowTcpForwarding.*/AllowTcpForwarding yes/' "$sshd_conf" || true
    if command -v systemctl >/dev/null 2>&1; then sudo systemctl restart sshd || sudo systemctl restart ssh; fi
  fi
}

print_usage() {
  cat <<EOF
Client usage:
  ssh -Y user@host            # trusted X11 forwarding
  ssh -X user@host            # untrusted X11 forwarding

Server test:
  xauth list && xclock &>/dev/null || glxinfo -B
EOF
}

install_pkgs
configure_sshd
print_usage
echo "X11 forwarding setup complete for $ENV (${DRY:+dry-run})."


