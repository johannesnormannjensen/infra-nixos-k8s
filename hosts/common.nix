{ config, pkgs, ... }:

let
  # Statisk Helm uden GUI-afhængigheder
  helm = pkgs.stdenv.mkDerivation {
    pname = "helm";
    version = "3.14.0";

    src = pkgs.fetchurl {
      url = "https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz";
      sha256 = "sha256-jOiVlfVnZTWGmiFmqv4dnKKCE1S1DiDbFtXBNSW3A58=";
    };

    unpackPhase = "tar -xzf $src";
    installPhase = ''
      mkdir -p $out/bin
      cp linux-amd64/helm $out/bin/helm
      chmod +x $out/bin/helm
    '';
  };
in {
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

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    htop
    tmux
    vim
    zsh
    docker
    kubectl
    ${helm} # Brug statisk Helm uden X11
  ];

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  # Fjern GUI helt
  services.xserver.enable = false;

  # Boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
