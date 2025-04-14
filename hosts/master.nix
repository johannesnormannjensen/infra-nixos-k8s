{ config, pkgs, ... }: {

  networking.hostName = "k8s-master";

  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    extraServerArgs = "--write-kubeconfig-mode=644";
  };

  environment.systemPackages = with pkgs; [
    k3s
    kubectl
    helm
  ];
}
