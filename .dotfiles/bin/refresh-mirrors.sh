#!/usr/bin/env bash
set -euo pipefail

# Arch Linux Mirror Refresh Script
# Fixes common package download issues by updating mirror list

# Check if running on Arch
if ! command -v pacman >/dev/null 2>&1; then
    echo "ERROR: This script is only for Arch Linux systems"
    exit 1
fi

# Helper function to run commands with sudo when needed
run_cmd() {
    if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        "$@"
    fi
}

echo "Refreshing Arch Linux mirrors..."

# First, try to update the package database with force refresh
echo "Force refreshing package databases..."
if ! run_cmd pacman -Syy --noconfirm; then
    echo "WARNING: Initial refresh failed, trying to fix mirrors..."
    
    # Install reflector if not present (for better mirror management)
    if ! command -v reflector >/dev/null 2>&1; then
        echo "Installing reflector for mirror management..."
        run_cmd pacman -S --needed --noconfirm reflector
    fi
    
    # Generate a fresh mirror list with the fastest mirrors
    echo "Generating fresh mirror list..."
    run_cmd reflector --country US,CA,GB,DE,FR --protocol https --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
    
    # Try refreshing again
    echo "Retrying package database refresh..."
    run_cmd pacman -Syy --noconfirm
fi

# Clean package cache to avoid conflicts
echo "Cleaning package cache..."
run_cmd pacman -Sc --noconfirm

echo "OK: Mirror refresh completed!"
echo ""
echo "Mirrors have been updated. Package installation should work better now."
echo "   You can now retry package installation."
