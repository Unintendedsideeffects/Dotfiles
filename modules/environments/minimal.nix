{ config, pkgs, lib, ... }:

{
  # Minimal environment configuration
  # Suitable for servers, containers, and headless systems

  dotfiles = {
    enableGui = false;
    enableDevelopment = false;
    enableMinimal = true;
  };

  # Essential packages only
  home.packages = with pkgs; [
    # Network utilities
    curl
    wget

    # Basic tools
    tree
    htop

    # Text editor
    vim
  ];

  # Minimal shell configuration
  programs.zsh = {
    shellAliases = {
      # Override package manager aliases for minimal environments
      update = lib.mkForce "echo 'Use nix to update packages'";
      install = lib.mkForce "nix-env -iA nixpkgs.";
    };
  };
}
