{ config, pkgs, lib, ... }:

{
  # Ranger file manager
  home.packages = with pkgs; [
    ranger
  ];

  # Link to existing ranger config
  xdg.configFile."ranger" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/ranger";
    recursive = true;
  };
}
