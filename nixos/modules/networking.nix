# Networking Configuration Module
{ config, lib, pkgs, ... }:

{
  options = {
    nixos-dotfiles.networking = {
      hostName = lib.mkOption {
        type = lib.types.str;
        default = "nixos";
        description = "System hostname";
      };

      enableNetworkManager = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable NetworkManager";
      };

      enableIwd = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use iwd instead of wpa_supplicant";
      };

      enableBluetooth = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Bluetooth support";
      };
    };
  };

  config = {
    networking = {
      hostName = config.nixos-dotfiles.networking.hostName;

      # NetworkManager
      networkmanager = lib.mkIf config.nixos-dotfiles.networking.enableNetworkManager {
        enable = true;
        wifi.backend = if config.nixos-dotfiles.networking.enableIwd then "iwd" else "wpa_supplicant";
      };

      # Firewall
      firewall = {
        enable = true;
        allowedTCPPorts = [ ];
        allowedUDPPorts = [ ];
        # Allow local network discovery
        allowPing = true;
      };

      # DNS
      nameservers = [ "1.1.1.1" "8.8.8.8" ];

      # Enable IPv6
      enableIPv6 = true;
    };

    # Bluetooth
    hardware.bluetooth = lib.mkIf config.nixos-dotfiles.networking.enableBluetooth {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };

    # Bluetooth manager
    services.blueman.enable = config.nixos-dotfiles.networking.enableBluetooth;

    # SSH
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
      openFirewall = false;  # Disable by default for security
    };

    # mDNS for .local domains
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        domain = true;
        workstation = true;
      };
    };
  };
}
