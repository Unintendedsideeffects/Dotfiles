{ config, pkgs, lib, ... }:

{
  imports = [
    # Editors
    ./neovim.nix

    # Terminal and multiplexers
    ./terminal.nix
    ./tmux.nix
    ./zellij.nix

    # Shell and prompt
    ./starship.nix

    # File managers
    ./yazi.nix
    ./ranger.nix

    # System monitors
    ./btop.nix

    # Window managers and desktop
    ./i3.nix
    ./sway.nix
    ./waybar.nix

    # Desktop utilities
    ./rofi.nix
    ./dunst.nix
    ./picom.nix
  ];
}
