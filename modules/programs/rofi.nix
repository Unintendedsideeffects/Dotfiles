{ config, pkgs, lib, ... }:

{
  programs.rofi = {
    enable = lib.mkIf config.dotfiles.enableGui true;
    package = pkgs.rofi-wayland;  # Use rofi-wayland for better Wayland support

    terminal = "${pkgs.ghostty}/bin/ghostty";

    # Link to existing rofi configuration with custom theme
    # The existing config.rasi has extensive custom styling
  };

  # Link to existing rofi config files for full customization
  xdg.configFile."rofi" = lib.mkIf config.dotfiles.enableGui {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/rofi";
    recursive = true;
  };

  # Additional rofi scripts
  home.packages = lib.mkIf config.dotfiles.enableGui (with pkgs; [
    rofi-calc
    rofi-emoji
    rofi-power-menu
  ]);
}
