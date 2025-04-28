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
      echo "[+] Installing nginx ingress controller"

      ${pkgs.kubectl}/bin/kubectl create namespace ingress-nginx --dry-run=client -o yaml | ${pkgs.kubectl}/bin/kubectl apply -f -

      ${pkgs.helm}/bin/helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
      ${pkgs.helm}/bin/helm repo update

      ${pkgs.helm}/bin/helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx
    '';
  };
}
