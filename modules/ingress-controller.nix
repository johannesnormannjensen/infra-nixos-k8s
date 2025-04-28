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
    autoSetup = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically run ingress setup a few minutes after boot via a systemd timer.";
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
      (pkgs.writeShellScriptBin "setup-ingress-controller" ''
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

        if ${pkgs.kubectl}/bin/kubectl get deployment ingress-nginx-controller -n ingress-nginx &> /dev/null; then
          echo "[+] Ingress controller already installed. Skipping setup."
          exit 0
        fi

        echo "[+] Installing nginx ingress controller"

        ${pkgs.kubectl}/bin/kubectl create namespace ingress-nginx --dry-run=client -o yaml | ${pkgs.kubectl}/bin/kubectl apply -f -

        ${pkgs.helm}/bin/helm repo add ingress-nginx https://kubernetes.github.io/helm-charts
        ${pkgs.helm}/bin/helm repo update

        ${pkgs.helm}/bin/helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
          --namespace ingress-nginx

        echo "[+] Done setting up ingress!"
      '')
    ];

    systemd.services.setup-ingress-controller-timer-service = lib.mkIf cfg.autoSetup {
      description = "Run ingress controller setup after boot";
      after = [ "network.target" ];
      wants = [ "k3s.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "run-setup-ingress-controller" ''
          ${pkgs.setup-ingress-controller}/bin/setup-ingress-controller
        ''}";
      };
    };

    systemd.timers.setup-ingress-controller-timer = lib.mkIf cfg.autoSetup {
      description = "Timer to run ingress controller setup after boot";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        Unit = "setup-ingress-controller-timer-service.service";
      };
    };
  };
}
