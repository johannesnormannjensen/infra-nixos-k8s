{ config, pkgs, ... }:

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
  ];

  networking.hostName = "k8s-master";

  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    extraFlags = "--write-kubeconfig-mode=644";
  };

  ingressController.enable = true;

  githubMonitoring = {
    enable = true;
    githubToken = "ghp_abc123...";
    githubOrg = "din-org";
    exporterImage = "my-registry.local:5000/github-exporter:latest";
    prometheusStoragePath = "/var/lib/prometheus-data";
    grafanaStoragePath = "/var/lib/grafana-data";
  };

  environment.etc."secrets".source = "/etc/secrets";

  system.stateVersion = "24.11";
}
