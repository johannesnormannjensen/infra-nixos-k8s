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
      (pkgs.writeShellScriptBin "deploy-github-monitoring" ''
        set -euo pipefail

        TOKEN=""
        GITHUB_REPO=""
        IMAGE=""

        while [[ $# -gt 0 ]]; do
          key="$1"
          case $key in
            --token)
              TOKEN="$2"
              shift; shift
              ;;
            --github-repo)
              GITHUB_REPO="$2"
              shift; shift
              ;;
            --image)
              IMAGE="$2"
              shift; shift
              ;;
            --grafana-url)
              GRAFANA_HOST="$2"
              shift; shift
              ;;
            *)
              echo "Unknown option $1"
              exit 1
              ;;
          esac
        done

        if [[ -z "$TOKEN" || -z "$GITHUB_REPO" || -z "$IMAGE" || -z "$GRAFANA_HOST" ]]; then
          echo "Usage: deploy-github-monitoring --token <token> --github-repo <org/repo> --image <image> --grafana-host <host>"
          exit 1
        fi

        REPOSITORY="$(echo "$IMAGE" | cut -d: -f1)"
        TAG="$(echo "$IMAGE" | cut -s -d: -f2 || echo "latest")"

        GRAFANA_HOST="${GRAFANA_HOST:-grafana.local}"  # Default value for GRAFANA_HOST

        echo "[+] Setting up monitoring namespace"
        kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

        echo "[+] Cleaning up any existing Grafana PVC"
        kubectl delete pvc grafana-pvc -n monitoring --ignore-not-found

        echo "[+] Creating Grafana PV/PVC"
        kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-pvc
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-path
EOF

        echo "[+] Adding Helm repos"
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update

        echo "[+] Ensuring 'local-path' is default storage class"
        kubectl patch storageclass local-path \
          -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' || true

        echo "[+] Installing kube-prometheus-stack"
        helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
          --namespace monitoring \
          --version 56.6.0 \
          --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplates[0].metadata.name=prometheus-db \
          --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplates[0].spec.accessModes[0]=ReadWriteOnce \
          --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplates[0].spec.resources.requests.storage=5Gi \
          --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplates[0].spec.storageClassName=local-path \
          --set grafana.persistence.enabled=true \
          --set grafana.persistence.existingClaim=grafana-pvc \
          --set grafana.adminPassword=admin

        echo "[+] Installing GitHub Exporter with image $REPOSITORY:$TAG"
        helm upgrade --install github-exporter ${toString ./charts/github-exporter} \
          --namespace monitoring \
          --set github.token="$TOKEN" \
          --set github.repo="$GITHUB_REPO" \
          --set image.repository="$REPOSITORY" \
          --set image.tag="$TAG"

        echo "[+] Setting up Grafana Ingress with TLS"
        kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-azure
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - "${GRAFANA_HOST}"
      secretName: grafana-tls
  rules:
    - host: "${GRAFANA_HOST}"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prometheus-stack-grafana
                port:
                  number: 80
EOF

        echo "[+] Checking pod status in 'monitoring' namespace..."
        kubectl get pods -n monitoring

        echo "[+] Done!"
      '')

      (pkgs.writeShellScriptBin "uninstall-github-monitoring" ''
        set -euo pipefail

        echo "[+] Deleting GitHub Exporter release"
        helm uninstall github-exporter -n monitoring || true

        echo "[+] Deleting Prometheus Stack release"
        helm uninstall prometheus-stack -n monitoring || true

        echo "[+] Deleting monitoring namespace"
        kubectl delete namespace monitoring || true

        echo "[+] Done!"
      '')

      (pkgs.writeShellScriptBin "status-github-monitoring" ''
        set -euo pipefail

        echo "🔎 Tjekker status på monitoring stack..."

        echo ""
        echo "📦 Pods i 'monitoring'-namespace:"
        kubectl get pods -n monitoring

        echo ""
        echo "💾 PVC'er i 'monitoring'-namespace:"
        kubectl get pvc -n monitoring

        echo ""
        echo "🌐 Ingress til Grafana:"
        kubectl get ingress -n monitoring grafana || echo "(ingen ingress endnu)"

        echo ""
        echo "🧪 Tester HTTP adgang til Grafana:"
        GRAFANA_IP=$(kubectl get svc -n monitoring prometheus-stack-grafana -o jsonpath='{.spec.clusterIP}')
        if curl --fail --connect-timeout 2 http://$GRAFANA_IP:80 > /dev/null 2>&1; then
          echo "✅ Grafana svarer på http://$GRAFANA_IP"
        else
          echo "⚠️  Kunne ikke kontakte Grafana via ClusterIP"
        fi

        echo ""
        echo "✅ Verifikation færdig!"
      '')
    ];
  };
}
