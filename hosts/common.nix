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
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOQdssF2Mz9XboO8WdJOt5eBIqJDngCFeM9UoxhxOzoX nixos-k8s-cluster"
    ];
    shell = pkgs.zsh;
    # Automatically create a basic .zshrc
    home = "/home/johannes";
  };

  environment.etc."zshrc-johannes".text = ''
    # Custom .zshrc for johannes
    export PATH=$HOME/bin:/run/wrappers/bin:$PATH
    setopt autocd
    setopt correct
    setopt interactivecomments
    HISTFILE=~/.zsh_history
    HISTSIZE=10000
    SAVEHIST=10000
  '';

  system.activationScripts.zshrc-johannes.text = ''
    ln -sf /etc/zshrc-johannes /home/johannes/.zshrc
    chown johannes:users /home/johannes/.zshrc
  '';

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

  # Enable systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
