#!/usr/bin/env bash
set -euo pipefail

ENV="unknown"
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  if [[ -d /etc/pve ]] || echo "${PRETTY_NAME:-}" | grep -qi proxmox; then
    ENV="proxmox"
  else
    case "$ID" in
      arch) ENV="arch" ;;
      debian|ubuntu) ENV="debian" ;;
    esac
  fi
fi

echo "Detected: $ENV"
for bin in git gpg rg fd fzf bat jq zsh; do
  if command -v "$bin" >/dev/null 2>&1; then
    echo "OK  - $bin"
  else
    echo "MISS- $bin"
  fi
done



