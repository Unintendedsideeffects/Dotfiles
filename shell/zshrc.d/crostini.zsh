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
export DISPLAY=:0
export PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native 