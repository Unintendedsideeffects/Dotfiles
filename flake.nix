{
  description = "Full NixOS system configuration with Home Manager integration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Neovim plugins and configurations
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, neovim-nightly-overlay, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ neovim-nightly-overlay.overlays.default ];
      };

      # Common modules for all Home Manager configurations
      commonModules = [
        ./modules/packages.nix
        ./modules/shell.nix
        ./modules/programs
        ./modules/git.nix
        ./modules/services.nix
        ./modules/scripts.nix
      ];

      # Helper to create home-manager configuration
      mkHomeConfiguration = { username, homeDirectory, extraModules ? [] }:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          modules = commonModules ++ extraModules ++ [
            {
              home = {
                inherit username homeDirectory;
                stateVersion = "24.05";
              };

              # Enable common features
              programs.home-manager.enable = true;

              # Allow unfree packages
              nixpkgs.config.allowUnfree = true;
            }
          ];
        };

      # Helper to create NixOS configuration
      mkNixosConfiguration = { hostname, system ? "x86_64-linux", modules ? [] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./nixos/configuration.nix
            home-manager.nixosModules.home-manager
            {
              networking.hostName = hostname;

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit inputs; };
                users.malcolm = import ./home.nix;

                # Share nixpkgs config with home-manager
                sharedModules = [
                  { nixpkgs.config.allowUnfree = true; }
                ];
              };

              # NixOS-specific options
              nixos-dotfiles = {
                boot.enableSystemdBoot = true;
                networking = {
                  hostName = hostname;
                  enableNetworkManager = true;
                  enableBluetooth = true;
                };
                desktop = {
                  enable = true;
                  enableX11 = true;
                  enableWayland = true;
                  windowManager = "both";
                  displayManager = "lightdm";
                };
                services = {
                  enableAudio = true;
                  enablePrinting = true;
                  enableDocker = false;
                  enableVirtualization = false;
                };
                users = {
                  mainUser = "malcolm";
                  mainUserFullName = "Malcolm";
                };
              };
            }
          ] ++ modules;
        };
    in
    {
      # Home Manager configurations for different environments
      homeConfigurations = {
        # Default/Arch Linux configuration
        "arch" = mkHomeConfiguration {
          username = builtins.getEnv "USER";
          homeDirectory = builtins.getEnv "HOME";
          extraModules = [
            ./modules/environments/arch.nix
            ./modules/environments/gui.nix
          ];
        };

        # Minimal/headless configuration
        "minimal" = mkHomeConfiguration {
          username = builtins.getEnv "USER";
          homeDirectory = builtins.getEnv "HOME";
          extraModules = [
            ./modules/environments/minimal.nix
          ];
        };

        # WSL configuration
        "wsl" = mkHomeConfiguration {
          username = builtins.getEnv "USER";
          homeDirectory = builtins.getEnv "HOME";
          extraModules = [
            ./modules/environments/wsl.nix
          ];
        };

        # Debian/Ubuntu configuration
        "debian" = mkHomeConfiguration {
          username = builtins.getEnv "USER";
          homeDirectory = builtins.getEnv "HOME";
          extraModules = [
            ./modules/environments/debian.nix
          ];
        };

        # Proxmox configuration
        "proxmox" = mkHomeConfiguration {
          username = builtins.getEnv "USER";
          homeDirectory = builtins.getEnv "HOME";
          extraModules = [
            ./modules/environments/proxmox.nix
            ./modules/environments/minimal.nix
          ];
        };

        # NixOS with GUI (for use with NixOS system config)
        "nixos-gui" = mkHomeConfiguration {
          username = "malcolm";
          homeDirectory = "/home/malcolm";
          extraModules = [
            ./modules/environments/gui.nix
          ];
        };

        # NixOS minimal (for servers)
        "nixos-minimal" = mkHomeConfiguration {
          username = "malcolm";
          homeDirectory = "/home/malcolm";
          extraModules = [
            ./modules/environments/minimal.nix
          ];
        };
      };

      # NixOS system configurations
      nixosConfigurations = {
        # Default desktop configuration
        "nixos-desktop" = mkNixosConfiguration {
          hostname = "nixos-desktop";
        };

        # Laptop configuration
        "nixos-laptop" = mkNixosConfiguration {
          hostname = "nixos-laptop";
          modules = [
            {
              # Laptop-specific settings
              services.tlp.enable = true;
              powerManagement.enable = true;
              services.thermald.enable = true;
            }
          ];
        };

        # Minimal server configuration
        "nixos-server" = mkNixosConfiguration {
          hostname = "nixos-server";
          modules = [
            {
              # Server-specific settings
              nixos-dotfiles.desktop.enable = false;
              services.openssh.openFirewall = true;
            }
          ];
        };

        # WSL configuration
        "nixos-wsl" = mkNixosConfiguration {
          hostname = "nixos-wsl";
          modules = [
            {
              # WSL-specific settings
              nixos-dotfiles.desktop.enable = false;
              boot.isContainer = true;
              wsl.enable = true;
            }
          ];
        };
      };

      # Packages exposed by this flake
      packages.${system} = {
        # Custom scripts package
        dotfiles-scripts = pkgs.callPackage ./nixos/packages/dotfiles-scripts.nix { };
      };

      # Development shell
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nil # Nix language server
          nixpkgs-fmt
          nixfmt
          home-manager
          git
        ];

        shellHook = ''
          echo "NixOS Dotfiles Development Environment"
          echo ""
          echo "Available commands:"
          echo "  nixos-rebuild - Rebuild NixOS system"
          echo "  home-manager  - Manage home configuration"
          echo "  nix flake check - Validate flake"
          echo "  nix flake show  - Show flake outputs"
        '';
      };

      # Formatter for 'nix fmt'
      formatter.${system} = pkgs.nixpkgs-fmt;

      # Installation templates
      templates = {
        default = {
          path = ./nixos;
          description = "NixOS system configuration template";
        };

        home-only = {
          path = ./modules;
          description = "Home Manager only configuration (for non-NixOS)";
        };
      };
    };
}
