#!/bin/bash
# WSL Configuration Setup Script

set -euo pipefail

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TEMPLATES_DIR="$(dirname "$SCRIPT_DIR")/templates"

# Check if running in WSL
# Multiple detection methods for better WSL reliability
if ! ([[ -n "${WSL_DISTRO_NAME:-}" ]] || \
      [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]] || \
      [[ -d /mnt/wsl ]] || \
      ([[ -f /proc/version ]] && grep -qi "microsoft" /proc/version && grep -qi "wsl" /proc/version) || \
      ([[ -r /proc/sys/kernel/osrelease ]] && grep -qi "microsoft" /proc/sys/kernel/osrelease 2>/dev/null && grep -qi "wsl" /proc/sys/kernel/osrelease 2>/dev/null)); then
    echo "This script is only for WSL environments"
    exit 1
fi

# Check if wsl.conf already exists and validate it
if [[ -f /etc/wsl.conf ]]; then
    echo "Checking existing /etc/wsl.conf for issues..."
    
    # Helper function to run commands with sudo when needed
    run_cmd() {
        if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
            sudo "$@"
        else
            "$@"
        fi
    }
    
    # Check for invalid configurations
    if grep -q "wsl2\." /etc/wsl.conf || grep -q 'kernelCommandLine = "' /etc/wsl.conf; then
        echo "❌ Found invalid WSL configuration format"
        echo "Backing up current configuration to /etc/wsl.conf.backup"
        run_cmd cp /etc/wsl.conf /etc/wsl.conf.backup
        
        echo "Creating corrected configuration..."
        run_cmd cp "$TEMPLATES_DIR/wsl.conf" /etc/wsl.conf
        
        # Replace template variables
        run_cmd sed -i "s/\${USER}/$USER/g" /etc/wsl.conf
        
        echo "✅ WSL configuration has been corrected"
        echo "⚠️  You need to restart WSL for changes to take effect:"
        echo "   wsl --shutdown"
        echo "   wsl"
    else
        echo "✅ Existing WSL configuration appears valid"
    fi
else
    # Helper function to run commands with sudo when needed
    run_cmd() {
        if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
            sudo "$@"
        else
            "$@"
        fi
    }
    
    echo "Creating new WSL configuration..."
    run_cmd cp "$TEMPLATES_DIR/wsl.conf" /etc/wsl.conf
    
    # Replace template variables
    run_cmd sed -i "s/\${USER}/$USER/g" /etc/wsl.conf
    
    echo "✅ WSL configuration created"
    echo "⚠️  You need to restart WSL for changes to take effect:"
    echo "   wsl --shutdown"
    echo "   wsl"
fi

echo "Current WSL configuration:"
cat /etc/wsl.conf