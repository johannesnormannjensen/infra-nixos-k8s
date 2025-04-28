{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.ingressController;
in
{
  options.ingressController = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable nginx ingress controller and disable Traefik in k3s.";
    };
  };

  config = mkIf cfg.enable {
    services.k3s = {
      enable = true;
      extraFlags = lib.mkAfter [
        "--disable traefik"
      ];
    };

    environment.systemPackages = with pkgs; [
      kubectl
      helm
    ];

    system.activationScripts.ingressController.text = ''
      set -euo pipefail

      echo "[+] Waiting for Kubernetes API to become ready..."
      for i in {1..60}; do
        if ${pkgs.kubectl}/bin/kubectl get nodes &> /dev/null; then
          echo "[+] Kubernetes API is ready!"
          break
        fi
        echo "Waiting for k3s API... ($i)"
        sleep 2
      done

      echo "[+] Installing nginx ingress controller"

      ${pkgs.kubectl}/bin/kubectl create namespace ingress-nginx --dry-run=client -o yaml | ${pkgs.kubectl}/bin/kubectl apply -f -

      ${pkgs.helm}/bin/helm repo add ingress-nginx https://kubernetes.github.io/helm-charts
      ${pkgs.helm}/bin/helm repo update

      ${pkgs.helm}/bin/helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx

      echo "[+] Done setting up ingress!"
    '';
  };
}
