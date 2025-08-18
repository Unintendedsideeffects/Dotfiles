#!/bin/bash
# WSL Configuration Setup Script

set -euo pipefail

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TEMPLATES_DIR="$(dirname "$SCRIPT_DIR")/templates"

# Check if running in WSL
if [[ ! -f /proc/version ]] || ! grep -q Microsoft /proc/version; then
    echo "This script is only for WSL environments"
    exit 1
fi

# Check if wsl.conf already exists and validate it
if [[ -f /etc/wsl.conf ]]; then
    echo "Checking existing /etc/wsl.conf for issues..."
    
    # Determine if we need sudo
    local use_sudo=""
    if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
        use_sudo="sudo"
    fi
    
    # Check for invalid dot notation keys
    if grep -q "wsl2\." /etc/wsl.conf; then
        echo "❌ Found invalid WSL configuration keys with dot notation"
        echo "Backing up current configuration to /etc/wsl.conf.backup"
        $use_sudo cp /etc/wsl.conf /etc/wsl.conf.backup
        
        echo "Creating corrected configuration..."
        $use_sudo cp "$TEMPLATES_DIR/wsl.conf" /etc/wsl.conf
        
        # Replace template variables
        $use_sudo sed -i "s/\${USER}/$USER/g" /etc/wsl.conf
        
        echo "✅ WSL configuration has been corrected"
        echo "⚠️  You need to restart WSL for changes to take effect:"
        echo "   wsl --shutdown"
        echo "   wsl"
    else
        echo "✅ Existing WSL configuration appears valid"
    fi
else
    # Determine if we need sudo
    local use_sudo=""
    if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
        use_sudo="sudo"
    fi
    
    echo "Creating new WSL configuration..."
    $use_sudo cp "$TEMPLATES_DIR/wsl.conf" /etc/wsl.conf
    
    # Replace template variables
    $use_sudo sed -i "s/\${USER}/$USER/g" /etc/wsl.conf
    
    echo "✅ WSL configuration created"
    echo "⚠️  You need to restart WSL for changes to take effect:"
    echo "   wsl --shutdown"
    echo "   wsl"
fi

echo "Current WSL configuration:"
cat /etc/wsl.conf