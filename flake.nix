{
  description = "NixOS Kubernetes Cluster with ARC tools and flake-based configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      supportedSystems = flake-utils.lib.defaultSystems;
      eachSystem = flake-utils.lib.eachDefaultSystem;
    in {
      nixosConfigurations = {
        master = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/master.nix
          ];
        };

        worker = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/worker.nix
          ];
        };
      };

      # Optional: place for default outputs like packages/apps per system
      packages = eachSystem (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          # Future packages can go here
        }
      );
    };
}
