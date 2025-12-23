{ config, pkgs, lib, ... }:

{
  services.picom = {
    enable = lib.mkIf config.dotfiles.enableGui true;

    backend = "glx";
    vSync = true;

    # Shadows
    shadow = true;
    shadowOffsets = [ 0 0 ];
    shadowOpacity = 0.15;
    shadowExclude = [
      "name = 'Notification'"
      "class_g = 'Conky'"
      "class_g ?= 'Notify-osd'"
      "class_g = 'Cairo-clock'"
      "_GTK_FRAME_EXTENTS@:c"
    ];

    # Fading
    fade = true;
    fadeDelta = 3;
    fadeSteps = [ 0.03 0.03 ];

    # Opacity
    activeOpacity = 1.0;
    inactiveOpacity = 1.0;
    menuOpacity = 1.0;

    opacityRules = [
      "90:class_g = 'URxvt' && focused"
      "60:class_g = 'URxvt' && !focused"
    ];

    # Other settings
    settings = {
      # Backend
      mark-wmwin-focused = true;
      mark-ovredir-focused = true;
      detect-rounded-corners = true;
      detect-client-opacity = true;
      use-ewmh-active-win = true;
      detect-transient = true;
      glx-no-stencil = true;
      glx-no-rebind-pixmap = true;

      # Rounded corners (requires picom-git)
      corner-radius = 8;
      round-borders = 1;

      # Blur (dual_kawase method)
      blur-method = "dual_kawase";
      blur-strength = 5;
      blur-background = true;
      blur-background-frame = true;
      blur-background-fixed = true;
      blur-background-exclude = [
        "window_type = 'dock'"
        "window_type = 'desktop'"
        "_GTK_FRAME_EXTENTS@:c"
      ];

      # Performance
      unredir-if-possible = true;

      # Window type settings
      wintypes = {
        tooltip = {
          fade = true;
          shadow = true;
          opacity = 0.85;
          focus = true;
          full-shadow = false;
        };
        dock = {
          shadow = false;
          clip-shadow-above = true;
        };
        dnd = {
          shadow = false;
        };
        popup_menu = {
          opacity = 0.95;
        };
        dropdown_menu = {
          opacity = 0.95;
        };
      };
    };
  };
}
