# User Configuration Module
{ config, lib, pkgs, ... }:

{
  options = {
    nixos-dotfiles.users = {
      mainUser = lib.mkOption {
        type = lib.types.str;
        default = "malcolm";
        description = "Primary user account name";
      };

      mainUserFullName = lib.mkOption {
        type = lib.types.str;
        default = "Malcolm";
        description = "Primary user full name";
      };

      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "networkmanager" "wheel" "audio" "video" "input" ];
        description = "Extra groups for the main user";
      };
    };
  };

  config = {
    # Define main user account
    users.users.${config.nixos-dotfiles.users.mainUser} = {
      isNormalUser = true;
      description = config.nixos-dotfiles.users.mainUserFullName;
      extraGroups = config.nixos-dotfiles.users.extraGroups
        ++ lib.optional config.nixos-dotfiles.services.enableDocker "docker"
        ++ lib.optional config.nixos-dotfiles.services.enableVirtualization "libvirtd";
      shell = pkgs.zsh;

      # Packages specific to this user
      packages = with pkgs; [ ];
    };

    # Set default shell to zsh
    users.defaultUserShell = pkgs.zsh;

    # Enable passwordless sudo for wheel group (optional, configure as needed)
    # security.sudo.wheelNeedsPassword = false;
  };
}
