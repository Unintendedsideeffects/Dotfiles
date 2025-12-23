{ config, pkgs, lib, ... }:

{
  xsession.windowManager.i3 = {
    enable = lib.mkIf config.dotfiles.enableGui true;
    package = pkgs.i3;

    # Use existing custom config
    # The config file has extensive custom keybindings and settings
    # We symlink it instead of managing it declaratively for flexibility
  };

  # Link to existing i3 configuration
  xdg.configFile."i3/config" = lib.mkIf config.dotfiles.enableGui {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/i3/config";
  };

  # i3-related packages
  home.packages = lib.mkIf config.dotfiles.enableGui (with pkgs; [
    i3status
    i3lock
    i3blocks
    i3-gaps  # i3 with gaps support
    # Additional i3 utilities
    autotiling  # Automatic tiling
    i3-layout-manager
  ]);
}
