#!/bin/bash
set -e

if [ ! -d "$HOME/.cfg" ]; then
  echo "Cloning dotfiles..."
  git clone --bare git@github.com:youruser/dotfiles.git $HOME/.cfg
  alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
  config checkout
  config config --local status.showUntrackedFiles no
else
  alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
  config pull
fi

echo "Dotfiles are set up! Use 'config status' to check for changes." 