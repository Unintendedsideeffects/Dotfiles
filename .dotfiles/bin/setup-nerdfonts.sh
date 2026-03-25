#!/usr/bin/env bash
set -euo pipefail

# Install Nerd Fonts from GitHub releases.
# Arch users get these via pacman (ttf-hack-nerd, etc.), so this script
# targets Debian, Proxmox, and RHEL-family systems where nerd fonts
# aren't available in the default repos.

FONT_DIR="${HOME}/.local/share/fonts/NerdFonts"
NERD_FONT_VERSION="${NERD_FONT_VERSION:-v3.3.0}"
BASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}"

# Fonts to install — these cover starship, eza, yazi, and general terminal use
FONTS=(
  "JetBrainsMono"
  "Hack"
)

DRY=false
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY=true
done

if ! command -v unzip >/dev/null 2>&1; then
  echo "ERROR: unzip is required but not installed."
  exit 1
fi

mkdir -p "$FONT_DIR"

installed=0
skipped=0

for font in "${FONTS[@]}"; do
  target_dir="$FONT_DIR/$font"
  if [[ -d "$target_dir" ]] && ls "$target_dir"/*.ttf &>/dev/null; then
    echo "  Already installed: $font Nerd Font"
    ((skipped++))
    continue
  fi

  url="${BASE_URL}/${font}.zip"

  if [[ "$DRY" == true ]]; then
    echo "  [DRY-RUN] Would download: $url"
    continue
  fi

  echo "  Downloading $font Nerd Font..."
  tmpfile=$(mktemp /tmp/nf-XXXXXX.zip)
  if curl -fsSL -o "$tmpfile" "$url"; then
    mkdir -p "$target_dir"
    unzip -qo "$tmpfile" -d "$target_dir"
    rm -f "$tmpfile"
    echo "  Installed: $font Nerd Font"
    ((installed++))
  else
    rm -f "$tmpfile"
    echo "  FAILED: Could not download $font (check version: $NERD_FONT_VERSION)"
  fi
done

# Rebuild font cache if we installed anything
if ((installed > 0)); then
  if command -v fc-cache >/dev/null 2>&1; then
    echo "  Rebuilding font cache..."
    fc-cache -f "$FONT_DIR" 2>/dev/null || true
  fi
fi

echo ""
echo "Nerd Fonts: $installed installed, $skipped already present"
echo "Location: $FONT_DIR"

if ((installed > 0)); then
  echo ""
  echo "ACTION REQUIRED: Set your terminal font to a Nerd Font."
  echo "  Recommended: 'JetBrainsMono Nerd Font' or 'Hack Nerd Font'"
  echo ""
  echo "  Ghostty:           font-family = JetBrainsMono Nerd Font"
  echo "  Windows Terminal:  Settings → Profiles → Font face"
  echo "  Kitty:             font_family JetBrainsMono Nerd Font"
  echo "  Alacritty:         font.normal.family = 'JetBrainsMono Nerd Font'"
  echo ""
  echo "  Without a Nerd Font, starship/eza/yazi will show broken glyphs."
fi
