{ config, pkgs, lib, ... }:

{
  # GUI environment configuration
  # Enables window managers, desktop applications, and GUI tools

  dotfiles = {
    enableGui = true;
    enableDevelopment = true;
    enableMinimal = false;
  };

  # GUI-specific packages are already defined in modules/packages.nix
  # and will be enabled via dotfiles.enableGui

  # Window manager configurations
  # Sway (Wayland)
  xdg.configFile."sway" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.config/sway") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/sway";
    recursive = true;
  };

  # i3 (X11)
  xdg.configFile."i3" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.config/i3") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/i3";
    recursive = true;
  };

  # Waybar (Wayland status bar)
  xdg.configFile."waybar" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.config/waybar") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/waybar";
    recursive = true;
  };

  # Rofi (Application launcher)
  xdg.configFile."rofi" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.config/rofi") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/rofi";
    recursive = true;
  };

  # Dunst (Notification daemon)
  xdg.configFile."dunst" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.config/dunst") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/dunst";
    recursive = true;
  };

  # Picom (Compositor)
  xdg.configFile."picom" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.config/picom") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/picom";
    recursive = true;
  };

  # X11 configuration files
  home.file.".xinitrc" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.dotfiles/shell/.xinitrc") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.dotfiles/shell/.xinitrc";
  };

  home.file.".Xresources" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.dotfiles/shell/.Xresources") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.dotfiles/shell/.Xresources";
  };

  # GUI-specific shell configuration
  programs.zsh = {
    initExtra = ''
      # GUI-specific environment setup

      # Start GUI session on TTY1 if configured
      if [[ -z "$DISPLAY" ]] && [[ "$XDG_VTNR" = "1" ]]; then
        # Check if GUI autostart is enabled
        GUI_AUTOSTART_CONFIG="$XDG_CONFIG_HOME/dotfiles/gui-autostart.conf"
        if [[ -f "$GUI_AUTOSTART_CONFIG" ]]; then
          source "$GUI_AUTOSTART_CONFIG"
          if [[ "$ENABLE_GUI_AUTOSTART" = "true" ]]; then
            case "$GUI_SESSION_TYPE" in
              "sway")
                exec sway
                ;;
              "i3")
                exec startx
                ;;
              *)
                # Default to sway if available, otherwise i3
                if command -v sway &> /dev/null; then
                  exec sway
                elif command -v startx &> /dev/null; then
                  exec startx
                fi
                ;;
            esac
          fi
        fi
      fi
    '';
  };

  # Font configuration
  xdg.configFile."fontconfig" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.config/fontconfig") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/fontconfig";
    recursive = true;
  };

  # Cursor configuration
  xdg.configFile."cursor" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.config/cursor") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/cursor";
    recursive = true;
  };
}
