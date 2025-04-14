{ config, pkgs, ... }:

{
  networking.useDHCP = true;
  networking.firewall.enable = false;

  time.timeZone = "Europe/Copenhagen";
  i18n.defaultLocale = "en_DK.UTF-8";
  i18n.supportedLocales = [
    "da_DK.UTF-8/UTF-8"
    "en_DK.UTF-8/UTF-8"
  ];

  users.users.johannes = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOQdssF2Mz9XboO8WdJOt5eBIqJDngCFeM9UoxhxOzoX nixos-k8s-cluster"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh.enable = true;

  virtualisation.docker.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    htop
    tmux
    vim
    bashInteractive
    docker
    kubectl
    kubernetes-helm   # ← Helm (be sure not to use "helm" as it is a different outdated package)
    gh                # ← GitHub CLI
  ];

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  services.xserver.enable = false;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
