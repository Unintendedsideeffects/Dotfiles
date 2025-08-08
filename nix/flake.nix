{
  description = "Dotfiles home-manager flake (non-NixOS compatible)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      mkHome = { system, username, homeDirectory ? "/home/${username}" }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs { inherit system; };
          modules = [
            ./modules/common/packages.nix
            ./modules/common/shell.nix
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
              programs.home-manager.enable = true;
            }
          ];
        };
    in {
      homeConfigurations = {
        # Change system/username as needed per host
        "malcolm@host" = mkHome { system = "x86_64-linux"; username = "malcolm"; };
      };
    };
}


