#!/bin/bash
#
# Auto-update script for Arch Linux
#
# Purpose: Automatically update system packages at scheduled times (via systemd timer)
#          and only reboot if updates were actually installed.
#
# How it works:
#   1. Runs informant to check for Arch news/announcements
#   2. Updates all packages using yay --noconfirm (AUR helper)
#   3. Detects if any packages were actually updated
#   4. If kernel was updated, rebuilds initramfs with mkinitcpio
#   5. Only reboots the system if updates were installed
#   6. Logs everything to /var/log/auto-update.log
#
# Usage: Triggered by auto-update.timer (scheduled for 2am daily)
#        Can also be run manually: sudo /usr/local/bin/auto-update.sh
#
# Installation:
#   - Copy to /usr/local/bin/auto-update.sh and make executable
#   - Install auto-update.service and auto-update.timer to /etc/systemd/system/
#   - Enable timer: systemctl enable --now auto-update.timer
#

LOG_FILE="/var/log/auto-update.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "=== Auto-update started at $DATE ===" >> "$LOG_FILE"

# Run informant to check for news
echo "Running informant..." >> "$LOG_FILE"
informant read >> "$LOG_FILE" 2>&1

# Capture yay output to a temporary file to analyze it
TEMP_YAY_LOG=$(mktemp)
echo "Running yay --noconfirm..." >> "$LOG_FILE"
yay --noconfirm > "$TEMP_YAY_LOG" 2>&1
YAY_EXIT=$?

# Append yay output to main log
cat "$TEMP_YAY_LOG" >> "$LOG_FILE"
echo "yay exit code: $YAY_EXIT" >> "$LOG_FILE"

# Check if any packages were actually upgraded/installed
# Look for specific success patterns from pacman/yay
UPDATES_INSTALLED=$(grep -E "^(upgrading|installing|removing)" "$TEMP_YAY_LOG" | wc -l)

rm -f "$TEMP_YAY_LOG"

if [ $UPDATES_INSTALLED -gt 0 ]; then
    echo "Updates were installed ($UPDATES_INSTALLED packages changed)" >> "$LOG_FILE"
    
    # Check if kernel was updated by looking for linux package in recent log entries
    if tail -n 100 "$LOG_FILE" | grep -q "^upgrading linux"; then
        echo "Kernel update detected, rebuilding initramfs..." >> "$LOG_FILE"
        mkinitcpio -p linux >> "$LOG_FILE" 2>&1
    else
        echo "No kernel update detected, skipping mkinitcpio" >> "$LOG_FILE"
    fi
    
    # Reboot the system since updates were installed
    echo "Rebooting system due to updates..." >> "$LOG_FILE"
    sync
    systemctl reboot
else
    echo "No updates installed, skipping reboot" >> "$LOG_FILE"
fi

echo "=== Auto-update finished at $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"
