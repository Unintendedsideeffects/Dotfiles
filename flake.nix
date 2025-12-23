{
  description = "Nix-based dotfiles configuration with Home Manager";

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

      # Common modules for all configurations
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
      };

      # NixOS configuration (optional, for full NixOS systems)
      nixosConfigurations = {
        default = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./nixos/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${builtins.getEnv "USER"} = import ./home.nix;
            }
          ];
        };
      };

      # Development shell
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nil # Nix language server
          nixpkgs-fmt
          home-manager
        ];
      };
    };
}
