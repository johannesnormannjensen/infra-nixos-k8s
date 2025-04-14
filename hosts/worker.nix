{ config, pkgs, ... }:

let
  hostname = builtins.getEnv "HOSTNAME";
  server = builtins.getEnv "K3S_SERVER";
  token = builtins.getEnv "K3S_TOKEN";
  labels = builtins.getEnv "K3S_NODE_LABELS";
  taints = builtins.getEnv "K3S_NODE_TAINTS";
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
    extraFlags = "--node-label ${labels} --node-taint ${taints}";
  };

  system.stateVersion = "24.11";
}
