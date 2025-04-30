{ config, pkgs, lib, ... }:

{
  options.certManager.enable = lib.mkEnableOption "Enable cert-manager tool";

  config = lib.mkIf config.certManager.enable {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "deploy-cert-manager" ''
        set -euo pipefail

        # Init vars
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --email) EMAIL="$2"; shift 2 ;;
            --client-id) CLIENT_ID="$2"; shift 2 ;;
            --client-secret) CLIENT_SECRET="$2"; shift 2 ;;
            --tenant-id) TENANT_ID="$2"; shift 2 ;;
            --subscription-id) SUBSCRIPTION_ID="$2"; shift 2 ;;
            --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
            --zone) ZONE="$2"; shift 2 ;;
            *) echo "❌ Unknown argument: $1"; exit 1 ;;
          esac
        done

        if [[ -z "''${EMAIL:-}" || -z "''${CLIENT_ID:-}" || -z "''${CLIENT_SECRET:-}" || -z "''${TENANT_ID:-}" || -z "''${SUBSCRIPTION_ID:-}" || -z "''${RESOURCE_GROUP:-}" || -z "''${ZONE:-}" ]]; then
          echo "Usage: deploy-cert-manager --email <email> --client-id <...> --client-secret <...> --tenant-id <...> --subscription-id <...> --resource-group <...> --zone <zone>"
          exit 1
        fi

        echo "[+] Creating namespace cert-manager"
        kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -

        echo "[+] Adding Helm repo"
        helm repo add jetstack https://charts.jetstack.io
        helm repo update

        echo "[+] Installing cert-manager Helm chart"
        helm upgrade --install cert-manager jetstack/cert-manager \
          --namespace cert-manager \
          --version v1.14.4 \
          --set installCRDs=true

        echo "[+] Creating Azure DNS secret"
        kubectl delete secret azuredns-config -n cert-manager --ignore-not-found

        kubectl create secret generic azuredns-config -n cert-manager \
          --from-literal=client-secret="$CLIENT_SECRET" \
          --from-literal=client-id="$CLIENT_ID" \
          --from-literal=tenant-id="$TENANT_ID" \
          --from-literal=subscription-id="$SUBSCRIPTION_ID" \
          --from-literal=resource-group="$RESOURCE_GROUP" \
          --from-literal=hosted-zone-name="$ZONE"

        echo "[+] Creating ClusterIssuer for Let's Encrypt via Azure DNS"
        kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-azure
spec:
  acme:
    email: "$EMAIL"
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-azure-account-key
    solvers:
    - dns01:
        azureDNS:
          clientID: "$CLIENT_ID"
          clientSecretSecretRef:
            name: azuredns-config
            key: client-secret
          subscriptionID: "$SUBSCRIPTION_ID"
          tenantID: "$TENANT_ID"
          resourceGroupName: "$RESOURCE_GROUP"
          hostedZoneName: "$ZONE"
          environment: AzurePublicCloud
EOF

        echo "[✓] cert-manager deployed & ClusterIssuer 'letsencrypt-azure' created!"
      '')
      (pkgs.writeShellScriptBin "uninstall-cert-manager" ''
        set -euo pipefail

        echo "[!] Warning: you are about to uninstall the cert-manager & remove all associated resources."
        echo "Press Ctrl+C to cancel or wait 5 seconds..."
        sleep 5

        echo "[+] Deleting ClusterIssuer 'letsencrypt-azure' (if it exists)"
        kubectl delete clusterissuer letsencrypt-azure --ignore-not-found

        echo "[+] Deleting Azure DNS secret"
        kubectl delete secret azuredns-config -n cert-manager --ignore-not-found

        echo "[+] Uninstalling cert-manager Helm release"
        helm uninstall cert-manager -n cert-manager || true

        echo "[+] Deleting CRDs"
        kubectl delete crds -l app.kubernetes.io/name=cert-manager || true

        echo "[+] Deleting cert-manager namespace"
        kubectl delete namespace cert-manager || true

        echo "[✓] cert-manager has been uninstalled"
      '')
      (pkgs.writeShellScriptBin "verify-cert-manager" ''
        set -euo pipefail

        echo "🔍 Verifying cert-manager status..."

        echo ""
        echo "📦 cert-manager pods:"
        kubectl get pods -n cert-manager || echo "(namespace not found)"

        echo ""
        echo "🪪 ClusterIssuers:"
        kubectl get clusterissuers || echo "(no ClusterIssuers found)"

        echo ""
        echo "📜 Certificates (cluster-wide):"
        kubectl get certificates --all-namespaces || echo "(no Certificates found)"

        echo ""
        echo "🔎 Checking if the cert-manager webhook is available:"
        if kubectl get apiservices | grep cert-manager; then
          echo "✅ cert-manager webhook is registered"
        else
          echo "⚠️  cert-manager webhook missing"
        fi

        echo ""
        echo "🔐 Checking TLS certificate for Grafana Ingress (grafana.local)..."
        CERT_SECRET=$(kubectl get ingress grafana -n monitoring -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null || true)

        if [[ -z "$CERT_SECRET" ]]; then
          echo "⚠️  No TLS secret referenced in ingress"
        elif ! kubectl get secret -n monitoring "$CERT_SECRET" &>/dev/null; then
          echo "❌ TLS secret '$CERT_SECRET' does not exist in namespace 'monitoring'"
        else
          echo "✅ Found TLS secret: $CERT_SECRET"
          
          echo "📅 Extracting certificate expiration date..."
          kubectl get secret "$CERT_SECRET" -n monitoring -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text | grep -A1 "Validity"

          EXPIRY=$(kubectl get secret "$CERT_SECRET" -n monitoring -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -enddate | cut -d= -f2)
          EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
          NOW_EPOCH=$(date +%s)
          DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

          echo "⏳ Certificate expires in $DAYS_LEFT days ($EXPIRY)"

          if [ "$DAYS_LEFT" -lt 14 ]; then
            echo "⚠️  WARNING: Certificate expires in less than 14 days!"
          fi
        fi

        echo ""
        echo "✅ Done verifying cert-manager"
      '')
    ];
  };
}
