{ config, pkgs, lib, ... }:

{
  # Kitty terminal
  programs.kitty = {
    enable = lib.mkIf config.dotfiles.enableGui true;
    theme = "Catppuccin-Mocha";
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };
    settings = {
      scrollback_lines = 10000;
      enable_audio_bell = false;
      update_check_interval = 0;
      clipboard_control = "write-clipboard write-primary read-clipboard read-primary";

      # Window layout
      remember_window_size = true;
      initial_window_width = 1200;
      initial_window_height = 800;

      # Tab bar
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";

      # Cursor
      cursor_shape = "block";
      cursor_blink_interval = 0;

      # Mouse
      mouse_hide_wait = 3.0;
      url_style = "curly";
      open_url_with = "default";

      # Performance
      repaint_delay = 10;
      input_delay = 3;
      sync_to_monitor = true;
    };
  };

  # Alacritty terminal (alternative)
  programs.alacritty = {
    enable = lib.mkIf config.dotfiles.enableGui true;
    settings = {
      env = {
        TERM = "xterm-256color";
      };

      window = {
        padding = {
          x = 10;
          y = 10;
        };
        dynamic_padding = true;
        decorations = "full";
        opacity = 0.95;
      };

      scrolling = {
        history = 10000;
        multiplier = 3;
      };

      font = {
        normal = {
          family = "JetBrainsMono Nerd Font";
          style = "Regular";
        };
        bold = {
          family = "JetBrainsMono Nerd Font";
          style = "Bold";
        };
        italic = {
          family = "JetBrainsMono Nerd Font";
          style = "Italic";
        };
        size = 11.0;
      };

      colors = {
        primary = {
          background = "#1e1e2e";
          foreground = "#cdd6f4";
        };
      };

      bell = {
        animation = "EaseOutExpo";
        duration = 0;
      };

      mouse = {
        hide_when_typing = true;
      };
    };
  };

  # Ghostty - use existing config
  xdg.configFile."ghostty" = lib.mkIf config.dotfiles.enableGui {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/ghostty";
    recursive = true;
  };
}
