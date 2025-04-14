{ config, pkgs, ... }:

{
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./common.nix
    ../modules/arc-tools.nix
    ../modules/arc-secrets.nix
  ];

  networking.hostName = "k8s-master";

  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    extraFlags = "--write-kubeconfig-mode=644";
  };

  environment.etc."secrets".source = "/etc/secrets";

  system.stateVersion = "24.11";
}
