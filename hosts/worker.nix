{ config, pkgs, ... }:

let
  hostname = builtins.getEnv "HOSTNAME";
  server = builtins.getEnv "K3S_SERVER";
  token = builtins.getEnv "K3S_TOKEN";
in
{
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./common.nix
  ];

  networking.hostName = hostname;

  services.k3s = {
    enable = true;
    role = "agent";
    inherit server token;
  };

  system.stateVersion = "24.11";
}
