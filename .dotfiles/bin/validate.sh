#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$DOTFILES_DIR/lib"

# shellcheck disable=SC1090
source "$LIB_DIR/detect.sh"

pass=0
warn=0
fail=0

ok()   { ((pass++)) || true; printf '  OK   %s\n' "$1"; }
miss() { ((fail++)) || true; printf '  MISS %s\n' "$1"; }
hint() { ((warn++)) || true; printf '  WARN %s — %s\n' "$1" "$2"; }

echo "========================================"
echo "Dotfiles Environment Validation"
echo "========================================"
echo ""
echo "Distro: $(df_os_pretty) ($(df_package_family 2>/dev/null || echo unknown))"
df_is_wsl && echo "WSL:    yes"
echo ""

# --- Core tools ---
echo "Core tools:"
for bin in git zsh curl; do
  if command -v "$bin" >/dev/null 2>&1; then
    ok "$bin"
  else
    miss "$bin"
  fi
done
echo ""

# --- CLI replacements ---
echo "CLI tools:"
for bin in rg fd fzf bat eza jq zoxide ranger; do
  # fd-find installs as fdfind on Debian
  if [[ "$bin" == "fd" ]]; then
    if command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1; then
      ok "fd"
    else
      miss "fd"
    fi
  # bat installs as batcat on Debian
  elif [[ "$bin" == "bat" ]]; then
    if command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1; then
      ok "bat"
    else
      miss "bat"
    fi
  else
    if command -v "$bin" >/dev/null 2>&1; then
      ok "$bin"
    else
      miss "$bin"
    fi
  fi
done
echo ""

# --- Prompt & history ---
echo "Shell enhancements:"
for bin in starship atuin; do
  if command -v "$bin" >/dev/null 2>&1; then
    ok "$bin"
  else
    miss "$bin"
  fi
done

# direnv
if command -v direnv >/dev/null 2>&1; then
  ok "direnv"
else
  hint "direnv" "optional but recommended"
fi
echo ""

# --- Dev tools ---
echo "Dev toolchain:"
for bin in nvim python3 node npm go gcc make cmake; do
  if command -v "$bin" >/dev/null 2>&1; then
    ok "$bin"
  else
    hint "$bin" "install via package list if needed"
  fi
done
echo ""

# --- Shell config ---
echo "Shell configuration:"
current_shell="$(getent passwd "${USER:-root}" 2>/dev/null | cut -d: -f7 || true)"
if [[ "$current_shell" == *zsh ]]; then
  ok "default shell is zsh"
else
  hint "shell" "default is ${current_shell:-unknown}, expected zsh"
fi

if [[ -f "$HOME/.zshrc" ]]; then
  ok ".zshrc exists"
else
  miss ".zshrc"
fi

if [[ -f "$HOME/.gitconfig" ]]; then
  ok ".gitconfig exists"
else
  miss ".gitconfig"
fi
echo ""

# --- Locale ---
echo "Locale:"
if locale -a 2>/dev/null | grep -Eqi 'utf-?8'; then
  ok "UTF-8 locale available"
else
  hint "locale" "no UTF-8 locale found — run setup-locale.sh"
fi

if [[ "${LANG:-}" =~ [Uu][Tt][Ff]-?8 ]]; then
  ok "LANG=$LANG"
else
  hint "LANG" "currently '${LANG:-unset}' — set to a UTF-8 locale for starship glyphs"
fi
echo ""

# --- Fonts ---
echo "Fonts:"
if command -v fc-list >/dev/null 2>&1; then
  if fc-list 2>/dev/null | grep -qi "nerd\|NF"; then
    ok "Nerd Font detected"
  else
    hint "fonts" "no Nerd Font found — run setup-nerdfonts.sh for starship/eza glyphs"
  fi
else
  hint "fc-list" "fontconfig not available, cannot check fonts"
fi
echo ""

# --- Summary ---
echo "========================================"
printf "Results: %d OK, %d warnings, %d missing\n" "$pass" "$warn" "$fail"
if ((fail > 0)); then
  echo "Status:  Some tools are missing"
elif ((warn > 0)); then
  echo "Status:  OK with warnings"
else
  echo "Status:  ALL OK"
fi
echo "========================================"

exit $((fail > 0 ? 1 : 0))
