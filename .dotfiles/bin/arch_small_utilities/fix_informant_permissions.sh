#!/bin/bash

set -e

echo "Fixing Informant permissions..."

if ! groups | grep -q informant; then
    echo "Adding user to informant group..."
    sudo usermod -aG informant "$USER"
    echo "WARNING: You need to log out and log back in for group membership to take effect"
fi

echo "Setting proper permissions for Informant directories and files..."
if [ -d "/var/cache/informant" ]; then
    sudo chmod -R 2750 /var/cache/informant
    sudo chown -R root:informant /var/cache/informant
    echo "Fixed permissions for /var/cache/informant"
fi

if [ -f "/var/lib/informant.dat" ]; then
    sudo chmod 640 /var/lib/informant.dat
    sudo chown root:informant /var/lib/informant.dat
    echo "Fixed permissions for /var/lib/informant.dat"
fi

echo "Creating user cache directory..."
mkdir -p "$HOME/.cache/informant"

echo "Permission fix complete!"
echo "Note: If you just added yourself to the informant group, please log out and log back in." 