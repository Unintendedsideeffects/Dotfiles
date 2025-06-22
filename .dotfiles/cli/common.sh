#!/usr/bin/env sh

# Exit on error
set -e

# XDG Base Directory Specification
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
: "${XDG_RUNTIME_DIR:=$HOME/.local/run}"

# Ensure XDG directories exist
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"

# Enhanced PATH management
path_append() {
    case ":$PATH:" in
        *:"$1":*) ;;
        *) PATH="${PATH:+$PATH:}$1" ;;
    esac
}

path_prepend() {
    case ":$PATH:" in
        *:"$1":*) ;;
        *) PATH="$1${PATH:+:$PATH}" ;;
    esac
}

# Add user binaries to PATH
path_prepend "$HOME/bin"
path_prepend "$HOME/.local/bin"

# Enhanced OS detection with more detailed information
detect_os() {
    local os
    local distro
    local wsl
    
    case "$(uname -s)" in
        Linux*)
            os="linux"
            if [ -f /etc/os-release ]; then
                distro=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
            fi
            if grep -q Microsoft /proc/version 2>/dev/null; then
                wsl=true
            fi
            ;;
        Darwin*)
            os="macos"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            os="windows"
            ;;
        *)
            os="unknown"
            ;;
    esac

    export OS="$os"
    export DISTRO="$distro"
    export IS_WSL="$wsl"
}

# Run OS detection
detect_os

# Load OS-specific configurations with error handling
load_os_config() {
    local config_file="$XDG_CONFIG_HOME/$OS/env.sh"
    if [ -f "$config_file" ]; then
        # shellcheck source=/dev/null
        . "$config_file" || {
            echo "Error loading $config_file" >&2
            return 1
        }
    fi
}

# Load OS-specific config
load_os_config

# Enhanced bash-preexec support with error handling
if [ -f /usr/share/bash-preexec/bash-preexec.sh ]; then
    # shellcheck source=/dev/null
    . /usr/share/bash-preexec/bash-preexec.sh || {
        echo "Error loading bash-preexec" >&2
    }
fi

# Clean up
unset -f path_append path_prepend detect_os load_os_config 