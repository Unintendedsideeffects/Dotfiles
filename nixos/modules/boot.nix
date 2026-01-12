# Boot Configuration Module
{ config, lib, pkgs, ... }:

{
  options = {
    nixos-dotfiles.boot = {
      enableSystemdBoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable systemd-boot bootloader";
      };

      enableGrub = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable GRUB bootloader (alternative to systemd-boot)";
      };

      grubDevice = lib.mkOption {
        type = lib.types.str;
        default = "nodev";
        description = "GRUB device (use 'nodev' for UEFI)";
      };
    };
  };

  config = lib.mkMerge [
    # Systemd-boot configuration
    (lib.mkIf config.nixos-dotfiles.boot.enableSystemdBoot {
      boot.loader = {
        systemd-boot = {
          enable = true;
          configurationLimit = 10;  # Keep last 10 generations
          editor = false;  # Disable boot entry editing for security
        };
        efi.canTouchEfiVariables = true;
        timeout = 3;  # Boot menu timeout
      };
    })

    # GRUB configuration
    (lib.mkIf config.nixos-dotfiles.boot.enableGrub {
      boot.loader = {
        grub = {
          enable = true;
          device = config.nixos-dotfiles.boot.grubDevice;
          efiSupport = config.nixos-dotfiles.boot.grubDevice == "nodev";
          configurationLimit = 10;
          useOSProber = true;  # Detect other operating systems
        };
        efi.canTouchEfiVariables = config.nixos-dotfiles.boot.grubDevice == "nodev";
        timeout = 3;
      };
    })

    # Common boot settings
    {
      boot = {
        # Kernel parameters
        kernelParams = [
          "quiet"  # Less verbose boot
          "splash"  # Show splash screen
        ];

        # Plymouth for boot splash
        plymouth.enable = true;

        # Support for various filesystems
        supportedFilesystems = [ "ntfs" "exfat" ];

        # Kernel modules
        kernelModules = [ "kvm-intel" ];  # Change to kvm-amd for AMD

        # tmpfs for /tmp
        tmp.useTmpfs = lib.mkDefault false;
        tmp.cleanOnBoot = lib.mkDefault true;
      };
    }
  ];
}
