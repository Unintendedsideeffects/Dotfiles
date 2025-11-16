{ config, pkgs, lib, ... }:

{
  # Proxmox server specific configuration

  dotfiles = {
    enableGui = false;
    enableDevelopment = false;
    enableMinimal = true;
  };

  # Proxmox-specific packages
  home.packages = with pkgs; [
    # Server utilities
    htop
    iotop
    iftop
    ncdu

    # Network tools
    tcpdump
    nmap
    curl
    wget
  ];

  # Proxmox-specific shell configuration
  programs.zsh = {
    shellAliases = {
      # Proxmox-specific aliases
      pve-update = "sudo apt update && sudo apt dist-upgrade -y";
      pve-reboot = "sudo systemctl reboot";
      pve-shutdown = "sudo systemctl poweroff";
    };

    initExtra = ''
      # Proxmox-specific environment setup

      # Load Proxmox-specific configurations if they exist
      [[ -f ~/.config/zsh/proxmox.zsh ]] && source ~/.config/zsh/proxmox.zsh
    '';
  };

  # Link to Proxmox-specific dotfiles
  xdg.configFile."zsh/proxmox.zsh" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.dotfiles/shell/zshrc.d/proxmox.zsh") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.dotfiles/shell/zshrc.d/proxmox.zsh";
  };
}
