{ config, pkgs, ... }:

{
  # Netværk
  networking.useDHCP = true;
  networking.firewall.enable = false;

  # Locale og tid
  time.timeZone = "Europe/Copenhagen";
  i18n.defaultLocale = "en_DK.UTF-8";

  # Bruger
  users.users.johannes = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOQdssF2Mz9XboO8WdJOt5eBIqJDngCFeM9UoxhxOzoX nixos-k8s-cluster"
    ];
  };

  # Sudo uden password
  security.sudo.wheelNeedsPassword = false;

  # SSH
  services.openssh.enable = true;

  # ZSH
  programs.zsh.enable = true;

  # Docker
  virtualisation.docker.enable = true;

  # Flakes og nix command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Pakker
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    htop
    tmux
    vim
    zsh
    docker
  ];
}
