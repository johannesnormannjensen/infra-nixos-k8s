{ config, pkgs, ... }: {

  imports = [
    /etc/nixos/hardware-configuration.nix
    ./common.nix
  ];

  networking.hostName = "k8s-master";

  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    extraFlags = "--write-kubeconfig-mode=644";
  };

  environment.systemPackages = with pkgs; [
    k3s kubectl helm
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "24.11";
}
