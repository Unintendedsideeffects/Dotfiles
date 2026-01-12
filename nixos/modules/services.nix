# System Services Configuration Module
{ config, lib, pkgs, ... }:

{
  options = {
    nixos-dotfiles.services = {
      enableAudio = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable audio with PipeWire";
      };

      enablePrinting = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable CUPS printing";
      };

      enableDocker = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Docker container runtime";
      };

      enableVirtualization = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable libvirt/QEMU virtualization";
      };
    };
  };

  config = {
    # Audio with PipeWire
    services.pipewire = lib.mkIf config.nixos-dotfiles.services.enableAudio {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;

      # Low latency configuration
      extraConfig.pipewire = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 1024;
          "default.clock.min-quantum" = 256;
          "default.clock.max-quantum" = 2048;
        };
      };
    };

    # Disable PulseAudio if using PipeWire
    hardware.pulseaudio.enable = lib.mkForce (!config.nixos-dotfiles.services.enableAudio);

    # CUPS printing
    services.printing = lib.mkIf config.nixos-dotfiles.services.enablePrinting {
      enable = true;
      drivers = with pkgs; [ gutenprint hplip ];
    };

    # Docker
    virtualisation.docker = lib.mkIf config.nixos-dotfiles.services.enableDocker {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
      storageDriver = "overlay2";
    };

    # Libvirt/QEMU
    virtualisation.libvirtd = lib.mkIf config.nixos-dotfiles.services.enableVirtualization {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
        ovmf = {
          enable = true;
          packages = [ pkgs.OVMFFull.fd ];
        };
      };
    };

    # GNOME Keyring
    services.gnome.gnome-keyring.enable = true;

    # Location services
    services.geoclue2.enable = true;

    # Udev rules
    services.udev.packages = with pkgs; [
      android-udev-rules
    ];

    # Thermald for Intel CPUs
    services.thermald.enable = true;

    # TLP for power management (laptops)
    services.tlp = {
      enable = lib.mkDefault false;  # Enable manually on laptops
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

        START_CHARGE_THRESH_BAT0 = 75;
        STOP_CHARGE_THRESH_BAT0 = 80;
      };
    };

    # Automatic system updates (disabled by default)
    system.autoUpgrade = {
      enable = false;
      allowReboot = false;
      dates = "weekly";
      flake = "/etc/nixos#default";
    };

    # Flatpak support (optional)
    services.flatpak.enable = lib.mkDefault false;

    # Locate database
    services.locate = {
      enable = true;
      package = pkgs.mlocate;
      interval = "daily";
      localuser = null;
    };

    # Fwupd for firmware updates
    services.fwupd.enable = true;

    # systemd services from original dotfiles
    systemd.user.services = {
      # Auto-update service (disabled by default)
      auto-update = {
        enable = false;
        description = "Automatic system updates";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -c 'sudo nixos-rebuild switch --flake /etc/nixos#default'";
        };
      };
    };

    systemd.user.timers = {
      auto-update = {
        enable = false;
        description = "Automatic system updates timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
        };
      };
    };
  };
}
