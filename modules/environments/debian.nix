{ config, pkgs, lib, ... }:

{
  # Debian/Ubuntu specific configuration

  dotfiles = {
    enableGui = lib.mkDefault false;
    enableDevelopment = true;
    enableMinimal = false;
  };

  # Debian-specific shell aliases
  programs.zsh = {
    shellAliases = {
      # APT aliases (for system packages not managed by Nix)
      update = "sudo apt update && sudo apt upgrade -y && nix flake update";
      install = "sudo apt install";
      remove = "sudo apt remove";
      search = "apt search";
      autoremove = "sudo apt autoremove -y";

      # Nix aliases for user packages
      nix-search = "nix search nixpkgs";
      nix-install = "nix profile install nixpkgs#";
      nix-remove = "nix profile remove";
      nix-list = "nix profile list";
    };

    initExtra = ''
      # Debian-specific environment setup

      # Load Debian-specific configurations if they exist
      [[ -f ~/.config/zsh/debian.zsh ]] && source ~/.config/zsh/debian.zsh
    '';
  };

  # Link to Debian-specific dotfiles
  xdg.configFile."zsh/debian.zsh" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.dotfiles/shell/zshrc.d/debian.zsh") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.dotfiles/shell/zshrc.d/debian.zsh";
  };
}
