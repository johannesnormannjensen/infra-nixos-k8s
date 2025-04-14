{
  description = "NixOS Kubernetes Cluster with ARC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-helm.url = "github:nix-community/flake-helm";
  };

  outputs = { self, nixpkgs, flake-utils, flake-helm, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        packages.arc-helm-values = pkgs.lib.mkForce (
          import ./helm/arc.nix {
            inherit pkgs;
            lib = pkgs.lib;
            inputs = { inherit flake-helm; };
          }
        );

        apps.arc-deploy = flake-helm.lib.mkHelmApp {
          inherit pkgs;
          releases = import ./helm/arc.nix {
            inherit pkgs lib;
            inputs = { inherit flake-helm; };
          };
        };

        defaultApp = self.apps.arc-deploy;
      });

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
}
