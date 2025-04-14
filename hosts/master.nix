{ config, pkgs, ... }: {

  networking.hostName = "k8s-master";

  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;

    serverConfig = {
      write-kubeconfig-mode = "644";
    };
  };

  environment.systemPackages = with pkgs; [
    k3s
    kubectl
    helm
  ];

  system.stateVersion = "24.11";
}
