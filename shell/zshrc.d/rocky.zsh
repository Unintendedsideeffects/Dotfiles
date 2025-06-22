# Rocky Linux (VMware) specific configuration

export IS_ROCKY=true
export IS_VM=true

# Rocky Linux specific aliases
alias shutdown="sudo poweroff"
alias reboot="sudo reboot"
alias update="sudo dnf update"
alias install="sudo dnf install"
alias remove="sudo dnf remove"

# Rocky Linux package management
export DNF_HISTORY_RECORD=true

# VMware-specific environment variables
export VMWARE=true

# Rocky Linux development tools
export PATH="$HOME/.local/bin:$PATH" 