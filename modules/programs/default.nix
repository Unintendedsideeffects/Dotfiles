{ config, pkgs, lib, ... }:

{
  imports = [
    ./tmux.nix
    ./neovim.nix
    ./starship.nix
    ./terminal.nix
    ./yazi.nix
    ./ranger.nix
  ];
}
