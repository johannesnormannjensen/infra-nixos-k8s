{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    (pkgs.writeShellScriptBin "arc-deploy" ''
      helm upgrade --install arc \
        oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
        --namespace custom-arc-systems \
        --create-namespace \
        --values /etc/nixos/arc/controller/values.yaml
    '')

    (pkgs.writeShellScriptBin "arc-uninstall" ''
      helm uninstall arc --namespace custom-arc-systems || true
    '')

    (pkgs.writeShellScriptBin "arc-runners-deploy" ''
      for file in /etc/nixos/arc/runner-set/*.yaml; do
        name=$(basename "$file" .yaml)
        echo "Deploying runner set: $name"
        helm upgrade --install "$name" \
          oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
          --namespace custom-arc-runners \
          --create-namespace \
          --values "$file"
      done
    '')

    (pkgs.writeShellScriptBin "arc-runners-upgrade" ''
      arc-runners-deploy
    '')

    (pkgs.writeShellScriptBin "arc-runners-uninstall" ''
      for file in /etc/nixos/arc/runner-set/*.yaml; do
        name=$(basename "$file" .yaml)
        echo "Uninstalling runner set: $name"
        helm uninstall "$name" --namespace custom-arc-runners || true
      done
    '')

    (pkgs.writeShellScriptBin "arc-status" ''
      kubectl get pods -n custom-arc-runners
    '')

    (pkgs.writeShellScriptBin "arc-status-watch" ''
      watch -n 2 kubectl get pods -n "custom-arc-runners"
    '')
  ];
}
