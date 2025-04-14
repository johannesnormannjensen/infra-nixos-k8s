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
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOQdssF2Mz9XboO8WdJOt5eBIqJDngCFeM9UoxhxOzoX nixos-k8s-cluster"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh.enable = true;
  programs.zsh.enable = true;

  virtualisation.docker.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Environment packages
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    htop
    tmux
    vim
    zsh
    docker
    helm
    kubectl
  ];

  # Set default kubeconfig
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
}
