# NixOS Configuration (Optional)
# This file is only needed if you're running a full NixOS system
# For other distributions, use Home Manager standalone

{ config, pkgs, lib, ... }:

{
  # This is a template NixOS configuration
  # Customize it according to your hardware and preferences

  imports = [
    # Include the results of the hardware scan
    # /etc/nixos/hardware-configuration.nix
  ];

  # Nix settings
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };

    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Bootloader configuration
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  # networking.hostName = "nixos";
  # networking.networkmanager.enable = true;

  # Time zone
  # time.timeZone = "America/New_York";

  # Internationalization
  # i18n.defaultLocale = "en_US.UTF-8";

  # Enable sound
  # sound.enable = true;
  # hardware.pulseaudio.enable = false;
  # services.pipewire = {
  #   enable = true;
  #   alsa.enable = true;
  #   alsa.support32Bit = true;
  #   pulse.enable = true;
  # };

  # Enable X11 or Wayland
  # services.xserver = {
  #   enable = true;
  #   displayManager.gdm.enable = true;
  #   desktopManager.gnome.enable = true;
  # };

  # Or for a minimal window manager setup:
  # services.xserver = {
  #   enable = true;
  #   windowManager.i3.enable = true;
  #   displayManager.lightdm.enable = true;
  # };

  # Enable Wayland (Sway)
  # programs.sway = {
  #   enable = true;
  #   wrapperFeatures.gtk = true;
  # };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    home-manager
  ];

  # Enable zsh system-wide
  programs.zsh.enable = true;

  # Define a user account
  # users.users.yourusername = {
  #   isNormalUser = true;
  #   description = "Your Name";
  #   extraGroups = [ "networkmanager" "wheel" "docker" ];
  #   shell = pkgs.zsh;
  # };

  # Enable Docker (optional)
  # virtualisation.docker.enable = true;

  # Enable SSH
  # services.openssh.enable = true;

  # Firewall
  # networking.firewall.allowedTCPPorts = [ ];
  # networking.firewall.allowedUDPPorts = [ ];
  # networking.firewall.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "24.05";
}
