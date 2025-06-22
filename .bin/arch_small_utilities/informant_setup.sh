#!/bin/bash

set -e

echo "Setting up Informant for Arch Linux news notifications..."

if ! command -v yay &> /dev/null; then
    echo "Error: yay is not installed. Please install yay first."
    exit 1
fi

echo "Installing informant..."
if ! yay -S informant --noconfirm --needed; then
    echo "Error: Failed to install informant"
    exit 1
fi

echo "Creating informant group..."
sudo groupadd -f informant

echo "Adding user to informant group..."
sudo usermod -aG informant "$USER"

echo "Setting up proper permissions for Informant directories and files..."
if [ -d "/var/cache/informant" ]; then
    sudo chmod -R 2750 /var/cache/informant
    sudo chown -R root:informant /var/cache/informant
fi

if [ -f "/var/lib/informant.dat" ]; then
    sudo chmod 640 /var/lib/informant.dat
    sudo chown root:informant /var/lib/informant.dat
fi

echo "Creating user cache directory..."
mkdir -p "$HOME/.cache/informant"

echo "Testing informant installation..."
if informant --version &> /dev/null; then
    echo "Informant installed successfully!"
else
    echo "Error: Informant installation verification failed"
    exit 1
fi

echo ""
echo "Setup complete! Important notes:"
echo "1. You need to log out and log back in for group membership to take effect"
echo "2. Informant will automatically check for news before system updates (pacman hook included)"
echo "3. Configuration is managed through dotfiles"
echo "4. Run 'informant check' to manually check for news"
echo "5. Run 'informant list' to see recent news items"
echo "6. Run 'informant read <item>' to read specific news items"
echo ""
echo "The pacman hook is automatically installed with the informant package."