{ config, pkgs, ... }:

{
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./common.nix
    ../modules/arc-tools.nix
  ];

  networking.hostName = "k8s-master";

  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    extraFlags = "--write-kubeconfig-mode=644";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "24.11";
}
