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
      "d /var/lib/prometheus-data 0755 65534 65534"
      "d /var/lib/grafana-data 0755 472 472"
    ];

    services.k3s.enable = true;

    environment.systemPackages = with pkgs; [
      kubectl
      kubernetes-helm
      (pkgs.writeShellScriptBin "setup-github-monitoring" ''
        set -euo pipefail

        TOKEN=""
        ORG=""
        IMAGE=""

        while [[ $# -gt 0 ]]; do
          key="$1"
          case $key in
            --token)
              TOKEN="$2"
              shift; shift
              ;;
            --org)
              ORG="$2"
              shift; shift
              ;;
            --image)
              IMAGE="$2"
              shift; shift
              ;;
            *)
              echo "Unknown option $1"
              exit 1
              ;;
          esac
        done

        if [[ -z "$TOKEN" || -z "$ORG" || -z "$IMAGE" ]]; then
          echo "Usage: setup-github-monitoring --token <token> --org <org> --image <image>"
          exit 1
        fi

        REPOSITORY="$(echo "$IMAGE" | cut -d: -f1)"
        TAG="$(echo "$IMAGE" | cut -s -d: -f2 || echo "latest")"

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

        echo "[+] Installing GitHub Exporter with image $REPOSITORY:$TAG"
        helm upgrade --install github-exporter ${toString ./charts/github-exporter} \
          --namespace monitoring \
          --set github.token="$TOKEN" \
          --set github.org="$ORG" \
          --set image.repository="$REPOSITORY" \
          --set image.tag="$TAG"

        echo "[+] Setting up Grafana Ingress"
        kubectl apply -f ${toString ./ingress-grafana.yaml}

        echo "[+] Done!"
      '')
      (pkgs.writeShellScriptBin "teardown-github-monitoring" ''
        set -euo pipefail

        echo "[+] Deleting GitHub Exporter release"
        helm uninstall github-exporter -n monitoring || true

        echo "[+] Deleting Prometheus Stack release"
        helm uninstall prometheus-stack -n monitoring || true

        echo "[+] Deleting monitoring namespace"
        kubectl delete namespace monitoring || true

        echo "[+] Done!"
      '')
    ];
  };
}
