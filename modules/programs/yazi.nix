{ config, pkgs, lib, ... }:

{
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;

    settings = {
      manager = {
        show_hidden = true;
        sort_by = "natural";
        sort_dir_first = true;
        sort_reverse = false;
      };

      preview = {
        max_width = 1000;
        max_height = 1000;
      };

      opener = {
        edit = [
          { exec = "nvim \"$@\""; }
        ];
        play = [
          { exec = "mpv \"$@\""; }
        ];
        open = [
          { exec = "xdg-open \"$@\""; }
        ];
      };
    };

    keymap = {
      manager.prepend_keymap = [
        { on = [ "g" "h" ]; exec = "cd ~"; }
        { on = [ "g" "c" ]; exec = "cd ~/.config"; }
        { on = [ "g" "d" ]; exec = "cd ~/Downloads"; }
        { on = [ "g" "D" ]; exec = "cd ~/Documents"; }
      ];
    };
  };

  # Link to existing yazi config if present
  xdg.configFile."yazi" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/yazi";
    recursive = true;
  };
}
