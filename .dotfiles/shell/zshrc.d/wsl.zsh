# WSL (Windows Subsystem for Linux) specific configuration

export IS_WSL=true

# WSL-specific aliases
alias explorer.exe="cmd.exe /C start"
alias notepad.exe="cmd.exe /C notepad"
alias code="code.exe"

# WSL file system integration
export WSL_DISTRO_NAME=$(grep -oP '(?<=^NAME=").*(?=")' /etc/os-release 2>/dev/null || echo "WSL")

# WSL-specific PATH additions
export PATH="/mnt/c/Windows/System32:$PATH"
export PATH="/mnt/c/Program Files/Git/cmd:$PATH"

# WSL display forwarding (if using WSLg)
if [[ -n "$WAYLAND_DISPLAY" ]]; then
  export DISPLAY="$WAYLAND_DISPLAY"
elif [[ -n "$DISPLAY" ]]; then
  export DISPLAY="$DISPLAY"
fi 