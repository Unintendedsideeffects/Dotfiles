{ config, pkgs, lib, ... }:

{
  # Arch Linux specific configuration

  dotfiles = {
    enableGui = lib.mkDefault false;  # Can be overridden
    enableDevelopment = true;
    enableMinimal = false;
  };

  # Arch-specific packages (that make sense with Nix)
  home.packages = with pkgs; [
    # AUR helper replacement - use nix instead
    # yay functionality is replaced by nix flakes
  ];

  # Arch-specific shell aliases
  programs.zsh = {
    shellAliases = {
      # Pacman aliases (for system packages not managed by Nix)
      update = "sudo pacman -Syu && nix flake update";
      install = "sudo pacman -S";
      remove = "sudo pacman -Rns";
      search = "pacman -Ss";

      # Nix aliases for user packages
      nix-search = "nix search nixpkgs";
      nix-install = "nix profile install nixpkgs#";
      nix-remove = "nix profile remove";
      nix-list = "nix profile list";
    };

    initExtra = ''
      # Arch-specific environment setup

      # Load Arch-specific configurations if they exist
      [[ -f ~/.config/zsh/arch.zsh ]] && source ~/.config/zsh/arch.zsh
    '';
  };

  # Link to Arch-specific dotfiles
  xdg.configFile."zsh/arch.zsh" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.dotfiles/shell/zshrc.d/arch.zsh") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.dotfiles/shell/zshrc.d/arch.zsh";
  };

  # Informant configuration (Arch news reader)
  xdg.configFile."informant" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.config/informant") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/informant";
    recursive = true;
  };

  # Pacman configuration
  xdg.configFile."pacman" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.config/pacman") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/pacman";
    recursive = true;
  };
}
