# Arch Linux specific configuration

export IS_ARCH=true

# Arch Linux specific aliases
alias update="sudo pacman -Syu"
alias install="sudo pacman -S"
alias remove="sudo pacman -R"
alias search="pacman -Ss"
alias aur="yay -S"

# Arch Linux package management
export PACMAN_AUTH="sudo"

# Arch Linux development tools
export PATH="$HOME/.local/bin:$PATH"

# Arch Linux specific environment variables
export EDITOR="vim"
export VISUAL="vim" 