#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to check if a command exists
check_command() {
    if command -v "$1" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed"
        return 0
    else
        echo -e "${RED}✗${NC} $1 is not installed"
        return 1
    fi
}

# Function to check if a file exists and is readable
check_file() {
    if [[ -r "$1" ]]; then
        echo -e "${GREEN}✓${NC} $1 exists and is readable"
        return 0
    else
        echo -e "${RED}✗${NC} $1 does not exist or is not readable"
        return 1
    fi
}

echo "Testing dotfiles setup..."

# Check essential commands
echo -e "\nChecking essential commands:"
check_command zsh
check_command git
check_command tmux

# Check essential files
echo -e "\nChecking essential files:"
check_file "$HOME/.zshrc"
check_file "$HOME/.gitconfig"
check_file "$HOME/.tmux.conf"

# Check if we're in WSL
if grep -qi microsoft /proc/version; then
    echo -e "\nWSL environment detected"
    check_file "$HOME/.wslconfig"
fi

# Check if we have a GUI
if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
    echo -e "\nGUI environment detected"
    check_file "$HOME/.Xresources"
fi

# Check if secrets directory exists and is gitignored
if [[ -d "secrets" ]]; then
    if git check-ignore -q secrets; then
        echo -e "${GREEN}✓${NC} secrets directory is properly gitignored"
    else
        echo -e "${RED}✗${NC} secrets directory is not gitignored"
    fi
fi

# Check if all scripts are executable
echo -e "\nChecking script permissions:"
for script in bin/*; do
    if [[ -x "$script" ]]; then
        echo -e "${GREEN}✓${NC} $script is executable"
    else
        echo -e "${RED}✗${NC} $script is not executable"
    fi
done

# Check if all scripts have proper shebangs
echo -e "\nChecking script shebangs:"
for script in bin/*; do
    if [[ -f "$script" ]]; then
        if head -n 1 "$script" | grep -q "^#!"; then
            echo -e "${GREEN}✓${NC} $script has a shebang"
        else
            echo -e "${RED}✗${NC} $script is missing a shebang"
        fi
    fi
done

echo -e "\nTest complete!" 