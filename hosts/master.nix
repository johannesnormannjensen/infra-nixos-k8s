{ config, pkgs, lib, ... }:

{
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./common.nix
    # Ingress controller
    ../modules/ingress-controller.nix
    # ARC specific modules
    ../modules/arc-tools.nix
    ../modules/arc-secrets.nix
    # Monitoring
    ../modules/github-monitoring/github-monitoring.nix
    # Cert-manager
    ../modules/cert-manager.nix
  ];

  networking.hostName = "k8s-master";

  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    extraFlags = lib.mkAfter [
      "--write-kubeconfig-mode=644"
    ];
  };

  # Deklarativ registries.yaml til container registry access
  environment.etc."rancher/k3s/registries.yaml".text = ''
    mirrors:
      "yourprivate.repo:32000":
        endpoint:
          - "http://yourprivate.repo:32000"
  '';

  ingressController = {
    enable = true;
    autoSetup = true;
  };

  githubMonitoring = {
    enable = true;
    prometheusStoragePath = "/var/lib/prometheus-data";
    grafanaStoragePath = "/var/lib/grafana-data";
  };

  certManager.enable = true;

  environment.etc."secrets".source = "/etc/secrets";

  system.stateVersion = "24.11";
}
