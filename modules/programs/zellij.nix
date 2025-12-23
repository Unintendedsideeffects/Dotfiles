{ config, pkgs, lib, ... }:

{
  programs.zellij = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;

    settings = {
      # Theme will be set based on existing theme files
      # but we can configure other settings here
      default_shell = "zsh";

      pane_frames = true;
      simplified_ui = false;

      # Keybindings mode
      default_mode = "normal";

      # Mouse support
      mouse_mode = true;

      # Scrollback
      scroll_buffer_size = 10000;

      # Copy mode settings
      copy_on_select = false;
    };
  };

  # Link to existing zellij theme files
  xdg.configFile."zellij/themes" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.config/zellij") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/zellij";
    recursive = true;
  };
}
