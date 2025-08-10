#!/usr/bin/env bash
set -euo pipefail

# Installer for Flexoki themes across common CLI/terminal apps.
# - Clones kepano/flexoki and installs theme files for detected apps
# - Does NOT overwrite existing configs; prints activation hints instead
#
# Usage:
#   setup-flexoki.sh [--variant dark|light]
#
# Supported apps (auto-detected by presence of config dir or binary):
#   - kitty, alacritty, wezterm, ghostty, foot
#   - tmux
#   - bat, git-delta (delta)
#   - nvim/vim (vim colors), helix (hx)

VARIANT="dark"
REPO_URL="https://github.com/kepano/flexoki.git"
INSTALL_NOTES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --variant)
      VARIANT="${2:-dark}"; shift 2;;
    --variant=*)
      VARIANT="${1#*=}"; shift 1;;
    -h|--help)
      echo "Usage: $0 [--variant dark|light]"; exit 0;;
    *) echo "Unknown argument: $1"; exit 1;;
  esac
done

VARIANT_LC="${VARIANT,,}"
if [[ "$VARIANT_LC" != "dark" && "$VARIANT_LC" != "light" ]]; then
  echo "Invalid --variant. Expected 'dark' or 'light'" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR" 2>/dev/null || true; }
trap cleanup EXIT

echo "Downloading Flexoki theme repo..."
if ! command -v git >/dev/null 2>&1; then
  echo "git is required to download Flexoki" >&2
  exit 1
fi

git clone --depth 1 "$REPO_URL" "$TMP_DIR/flexoki" >/dev/null 2>&1 || {
  echo "Failed to clone $REPO_URL" >&2; exit 1;
}
FLEX_DIR="$TMP_DIR/flexoki"

mkdir -p "$HOME/.config" "$HOME/.local/share"

# --- helpers ---
first_match_or_empty() {
  # args: dir, glob1 [glob2 ...]
  local search_dir="$1"; shift || true
  local glob_pattern path
  shopt -s nullglob globstar
  for glob_pattern in "$@"; do
    for path in "$search_dir"/$glob_pattern; do
      echo "$path"
      shopt -u nullglob globstar
      return 0
    done
  done
  shopt -u nullglob globstar
  return 1
}

copy_if_exists() {
  # args: source_file dest_path
  local src="$1"; local dest="$2"
  if [[ -n "${src:-}" && -f "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "  • Installed: ${dest/#$HOME/~}"
    return 0
  fi
  return 1
}

echo "Installing Flexoki ($VARIANT_LC) where supported..."

# kitty
if [[ -d "$HOME/.config/kitty" ]] || command -v kitty >/dev/null 2>&1; then
  src=$(first_match_or_empty "$FLEX_DIR" "**/kitty/**${VARIANT_LC}*.conf" "**/kitty/**flexoki*.conf" || true)
  dest="$HOME/.config/kitty/themes/flexoki-${VARIANT_LC}.conf"
  if copy_if_exists "${src:-}" "$dest"; then
    INSTALL_NOTES+=("kitty: add 'include themes/flexoki-${VARIANT_LC}.conf' to ~/.config/kitty/kitty.conf")
  fi
fi

# alacritty
if [[ -d "$HOME/.config/alacritty" ]] || command -v alacritty >/dev/null 2>&1; then
  src=$(first_match_or_empty "$FLEX_DIR" "**/alacritty/**${VARIANT_LC}*.y?(a)ml" "**/alacritty/**flexoki*.y?(a)ml" || true)
  dest="$HOME/.config/alacritty/colors/flexoki-${VARIANT_LC}.yml"
  if copy_if_exists "${src:-}" "$dest"; then
    INSTALL_NOTES+=("alacritty: in alacritty.yml add: import: [~/.config/alacritty/colors/flexoki-${VARIANT_LC}.yml]")
  fi
fi

# wezterm
if [[ -d "$HOME/.config/wezterm" ]] || command -v wezterm >/dev/null 2>&1; then
  src=$(first_match_or_empty "$FLEX_DIR" "**/wezterm/**${VARIANT_LC}*.lua" "**/wezterm/**flexoki*.lua" || true)
  dest="$HOME/.config/wezterm/colors/flexoki-${VARIANT_LC}.lua"
  if copy_if_exists "${src:-}" "$dest"; then
    INSTALL_NOTES+=("wezterm: require('colors/flexoki-${VARIANT_LC}') or set color_scheme accordingly")
  fi
fi

# ghostty
if [[ -d "$HOME/.config/ghostty" ]]; then
  src=$(first_match_or_empty "$FLEX_DIR" "**/ghostty/**${VARIANT_LC}*" "**/ghostty/**Flexoki*" || true)
  if [[ -n "${src:-}" ]]; then
    dest_dir="$HOME/.config/ghostty/themes"
    mkdir -p "$dest_dir"
    cp -r "$src" "$dest_dir/" 2>/dev/null || cp "$src" "$dest_dir/" 2>/dev/null || true
    echo "  • Installed: ${dest_dir/#$HOME/~} (ghostty themes)"
    INSTALL_NOTES+=("ghostty: set 'theme = Flexoki ${VARIANT_LC^}' in ~/.config/ghostty/config if available")
  fi
fi

# foot
if [[ -d "$HOME/.config/foot" ]] || command -v foot >/dev/null 2>&1; then
  src=$(first_match_or_empty "$FLEX_DIR" "**/foot/**${VARIANT_LC}*.ini" "**/foot/**flexoki*.ini" || true)
  dest="$HOME/.config/foot/themes/flexoki-${VARIANT_LC}.ini"
  copy_if_exists "${src:-}" "$dest" >/dev/null || true
fi

# tmux
if command -v tmux >/dev/null 2>&1 || [[ -f "$HOME/.tmux.conf" ]] || [[ -d "$HOME/.config/tmux" ]]; then
  src=$(first_match_or_empty "$FLEX_DIR" "**/tmux/**${VARIANT_LC}*.tmux" "**/tmux/**flexoki*.tmux" "**/tmux/**.conf" || true)
  dest="$HOME/.config/tmux/flexoki-${VARIANT_LC}.tmux"
  if copy_if_exists "${src:-}" "$dest"; then
    INSTALL_NOTES+=("tmux: add 'source-file ~/.config/tmux/flexoki-${VARIANT_LC}.tmux' to your tmux config")
  fi
fi

# bat
if command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1; then
  src=$(first_match_or_empty "$FLEX_DIR" "**/bat/**flexoki*.tmTheme" "**/*.tmTheme" || true)
  dest="$HOME/.config/bat/themes/Flexoki-${VARIANT_LC}.tmTheme"
  if copy_if_exists "${src:-}" "$dest"; then
    (command -v bat >/dev/null 2>&1 && bat cache --build) || (command -v batcat >/dev/null 2>&1 && batcat cache --build) || true
    INSTALL_NOTES+=("bat: set '--theme=Flexoki-${VARIANT_LC}' or export BAT_THEME=Flexoki-${VARIANT_LC}")
  fi
fi

# delta (git diff)
if command -v delta >/dev/null 2>&1; then
  src=$(first_match_or_empty "$FLEX_DIR" "**/delta/**${VARIANT_LC}*.gitconfig" "**/delta/**flexoki*.gitconfig" || true)
  dest="$HOME/.config/delta/flexoki-${VARIANT_LC}.gitconfig"
  if copy_if_exists "${src:-}" "$dest"; then
    INSTALL_NOTES+=("delta: include in ~/.gitconfig -> [include] path = ~/.config/delta/flexoki-${VARIANT_LC}.gitconfig")
  fi
fi

# neovim/vim
if command -v nvim >/dev/null 2>&1 || command -v vim >/dev/null 2>&1 || [[ -d "$HOME/.config/nvim" ]]; then
  src=$(first_match_or_empty "$FLEX_DIR" "**/vim/**/colors/*flexoki*.vim" "**/nvim/**/colors/*flexoki*.vim" || true)
  dest="$HOME/.config/nvim/colors/flexoki.vim"
  if copy_if_exists "${src:-}" "$dest"; then
    INSTALL_NOTES+=("nvim/vim: add 'colorscheme flexoki' (and 'set background=${VARIANT_LC}') in your config")
  fi
fi

# helix
if command -v hx >/dev/null 2>&1 || [[ -d "$HOME/.config/helix" ]]; then
  src=$(first_match_or_empty "$FLEX_DIR" "**/helix/**${VARIANT_LC}*.toml" "**/helix/**flexoki*.toml" || true)
  dest="$HOME/.config/helix/themes/flexoki-${VARIANT_LC}.toml"
  if copy_if_exists "${src:-}" "$dest"; then
    INSTALL_NOTES+=("helix: set 'theme = \"flexoki-${VARIANT_LC}\"' in ~/.config/helix/config.toml")
  fi
fi

echo
echo "Flexoki installation completed."
if ((${#INSTALL_NOTES[@]})); then
  echo "Activation hints:"
  for note in "${INSTALL_NOTES[@]}"; do
    echo " - ${note}"
  done
fi
