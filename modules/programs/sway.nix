{ config, pkgs, lib, ... }:

{
  wayland.windowManager.sway = {
    enable = lib.mkIf config.dotfiles.enableGui true;
    package = pkgs.sway;

    # Use existing custom config
    # Symlink the existing config for full customization
    wrapperFeatures.gtk = true;

    extraOptions = [
      "--unsupported-gpu"  # For NVIDIA or other GPUs
    ];

    # System integration
    systemd.enable = true;
    xwayland = true;
  };

  # Link to existing sway configuration
  xdg.configFile."sway/config" = lib.mkIf config.dotfiles.enableGui {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/sway/config";
  };

  # Sway-related packages
  home.packages = lib.mkIf config.dotfiles.enableGui (with pkgs; [
    # Wayland utilities
    wl-clipboard       # Clipboard utilities
    wl-mirror         # Screen mirroring
    wlr-randr         # Display configuration
    swaybg            # Wallpaper manager
    swaylock          # Screen locker
    swayidle          # Idle management
    swaynotificationcenter  # Notification center

    # Screenshots and screen recording
    grim              # Screenshot utility
    slurp             # Region selector
    wf-recorder       # Screen recorder

    # Additional Wayland tools
    wtype             # xdotool for Wayland
    ydotool           # Another keyboard/mouse tool
    wev               # Wayland event viewer
    wayvnc            # VNC server for Wayland
  ]);
}
