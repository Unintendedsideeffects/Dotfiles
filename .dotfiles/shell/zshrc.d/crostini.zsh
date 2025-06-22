# Crostini (Pixelbook) specific configuration

export CHROMEBOOK=true
export PATH="$HOME/.local/bin:$PATH"

# Crostini-specific aliases
alias open="xdg-open"
alias chrome="google-chrome"
alias files="nautilus"

# Crostini file system integration
export CHROMEOS_FILES_DIR="/mnt/chromeos"

# Crostini-specific environment variables
# Patch for apps requiring X11-style $DISPLAY
if [[ -z "$DISPLAY" && -n "$WAYLAND_DISPLAY" ]]; then
  export DISPLAY=:0
fi
export PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native 