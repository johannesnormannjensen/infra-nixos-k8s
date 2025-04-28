{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.githubMonitoring;
in
{
  options.githubMonitoring = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable GitHub monitoring stack helper script.";
    };
    githubToken = mkOption {
      type = types.str;
      description = "GitHub Personal Access Token.";
    };
    githubOrg = mkOption {
      type = types.str;
      description = "GitHub Organization name.";
    };
    exporterImage = mkOption {
      type = types.str;
      description = "The full image reference for GitHub Exporter (e.g. my-registry.local:5000/github-exporter:latest)";
    };
    prometheusStoragePath = mkOption {
      type = types.path;
      default = "/var/lib/prometheus-data";
      description = "HostPath for Prometheus data persistence.";
    };
    grafanaStoragePath = mkOption {
      type = types.path;
      default = "/var/lib/grafana-data";
      description = "HostPath for Grafana data persistence.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    systemd.tmpfiles.rules = [
      "d ${cfg.prometheusStoragePath} 0755 65534 65534"
      "d ${cfg.grafanaStoragePath} 0755 472 472"
    ];

    services.k3s.enable = true;

    environment.systemPackages = with pkgs; [
      kubectl
      helm
      (pkgs.writeShellScriptBin "setup-github-monitoring" ''
        set -euo pipefail

        echo "[+] Setting up monitoring namespace"
        kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

        echo "[+] Adding Helm repos"
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update

        echo "[+] Installing kube-prometheus-stack"
        helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
          --namespace monitoring \
          --version 56.6.0 \
          --set prometheus.prometheusSpec.storageSpec.volumeMounts[0].name=prometheus-storage \
          --set prometheus.prometheusSpec.storageSpec.volumeMounts[0].mountPath=/prometheus \
          --set prometheus.prometheusSpec.storageSpec.volumes[0].name=prometheus-storage \
          --set prometheus.prometheusSpec.storageSpec.volumes[0].hostPath.path=${cfg.prometheusStoragePath} \
          --set prometheus.prometheusSpec.storageSpec.volumes[0].hostPath.type=DirectoryOrCreate \
          --set grafana.extraVolumeMounts[0].name=grafana-storage \
          --set grafana.extraVolumeMounts[0].mountPath=/var/lib/grafana \
          --set grafana.extraVolumes[0].name=grafana-storage \
          --set grafana.extraVolumes[0].hostPath.path=${cfg.grafanaStoragePath} \
          --set grafana.extraVolumes[0].hostPath.type=DirectoryOrCreate \
          --set grafana.adminPassword=admin

        echo "[+] Installing GitHub Exporter"
        helm upgrade --install github-exporter ${toString ./charts/github-exporter} \
          --namespace monitoring \
          --set github.token="${cfg.githubToken}" \
          --set github.org="${cfg.githubOrg}" \
          --set image.repository="${builtins.head (builtins.split ":" cfg.exporterImage)}" \
          --set image.tag="${builtins.elemAt (builtins.split ":" cfg.exporterImage) 1}"

        echo "[+] Setting up Grafana Ingress"
        kubectl apply -f ${toString ./ingress-grafana.yaml}

        echo "[+] Done!"
      '')

      (pkgs.writeShellScriptBin "teardown-github-monitoring" ''
        set -euo pipefail

        echo "[+] Deleting GitHub Exporter"
        helm uninstall github-exporter -n monitoring || true

        echo "[+] Deleting Prometheus stack"
        helm uninstall prometheus-stack -n monitoring || true

        echo "[+] Deleting Grafana Ingress"
        kubectl delete ingress grafana -n monitoring || true

        echo "[+] Deleting monitoring namespace"
        kubectl delete namespace monitoring || true

        echo "[+] Done tearing down GitHub Monitoring stack!"
      '')
    ];
  };
}
