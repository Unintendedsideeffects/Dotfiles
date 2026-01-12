# Desktop Environment Configuration Module
{ config, lib, pkgs, ... }:

{
  options = {
    nixos-dotfiles.desktop = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable desktop environment";
      };

      enableX11 = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable X11 server";
      };

      enableWayland = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Wayland support";
      };

      windowManager = lib.mkOption {
        type = lib.types.enum [ "i3" "sway" "both" "none" ];
        default = "both";
        description = "Window manager to enable";
      };

      displayManager = lib.mkOption {
        type = lib.types.enum [ "lightdm" "gdm" "sddm" "none" ];
        default = "lightdm";
        description = "Display manager to use";
      };
    };
  };

  config = lib.mkIf config.nixos-dotfiles.desktop.enable {
    # X11 configuration
    services.xserver = lib.mkIf config.nixos-dotfiles.desktop.enableX11 {
      enable = true;

      # Keyboard layout
      xkb = {
        layout = "us";
        variant = "";
      };

      # libinput for touchpad
      libinput = {
        enable = true;
        touchpad = {
          naturalScrolling = true;
          tapping = true;
          disableWhileTyping = true;
        };
      };

      # i3 window manager
      windowManager.i3 = lib.mkIf (config.nixos-dotfiles.desktop.windowManager == "i3" ||
                                     config.nixos-dotfiles.desktop.windowManager == "both") {
        enable = true;
        extraPackages = with pkgs; [
          i3status
          i3lock
          i3blocks
          dmenu
          rofi
        ];
      };

      # Display managers
      displayManager = {
        lightdm = lib.mkIf (config.nixos-dotfiles.desktop.displayManager == "lightdm") {
          enable = true;
          greeters.gtk.enable = true;
        };

        gdm = lib.mkIf (config.nixos-dotfiles.desktop.displayManager == "gdm") {
          enable = true;
          wayland = config.nixos-dotfiles.desktop.enableWayland;
        };

        sddm = lib.mkIf (config.nixos-dotfiles.desktop.displayManager == "sddm") {
          enable = true;
          wayland.enable = config.nixos-dotfiles.desktop.enableWayland;
        };
      };
    };

    # Sway (Wayland)
    programs.sway = lib.mkIf (config.nixos-dotfiles.desktop.enableWayland &&
                               (config.nixos-dotfiles.desktop.windowManager == "sway" ||
                                config.nixos-dotfiles.desktop.windowManager == "both")) {
      enable = true;
      wrapperFeatures.gtk = true;
      extraPackages = with pkgs; [
        swaylock
        swayidle
        swaybg
        waybar
        wl-clipboard
        grim
        slurp
        mako
        wofi
        rofi-wayland
      ];
    };

    # XDG portals for screen sharing, etc.
    xdg.portal = {
      enable = true;
      wlr.enable = config.nixos-dotfiles.desktop.enableWayland;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ] ++ lib.optionals config.nixos-dotfiles.desktop.enableWayland [
        xdg-desktop-portal-wlr
      ];
    };

    # Fonts
    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        noto-fonts
        noto-fonts-emoji
        noto-fonts-cjk
        liberation_ttf
        fira-code
        fira-code-symbols
        font-awesome
        dejavu_fonts
        (nerdfonts.override { fonts = [ "JetBrainsMono" "Hack" "FiraCode" "Iosevka" ]; })
      ];

      fontconfig = {
        enable = true;
        defaultFonts = {
          serif = [ "Noto Serif" "DejaVu Serif" ];
          sansSerif = [ "Noto Sans" "DejaVu Sans" ];
          monospace = [ "JetBrainsMono Nerd Font" "FiraCode Nerd Font" "DejaVu Sans Mono" ];
          emoji = [ "Noto Color Emoji" ];
        };
      };
    };

    # OpenGL/Graphics
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        mesa
        vulkan-loader
        vulkan-validation-layers
      ];
    };
  };
}
