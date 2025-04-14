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

  # ARC controller Helm release
  services.kubernetes.helmReleases.arc-controller = {
    chart = "gha-runner-scale-set-controller";
    repo = "oci://ghcr.io/actions/actions-runner-controller-charts";
    version = "0.11.0";
    namespace = "custom-arc-systems";
    createNamespace = true;
    valuesFiles = [ ./arc/controller/values.yaml ];
  };

  environment.systemPackages = with pkgs; [
    k3s
    kubectl
    helm
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "24.11";
}
