{ pkgs, ... }:

let
  controllerValues = ./../arc/controller/values.yaml;
  runnerSetDir = ./../arc/runner-set;
in {
  environment.systemPackages = with pkgs; [

    # ARC controller install
    (pkgs.writeShellScriptBin "arc-deploy" ''
      unset DISPLAY
      helm upgrade --install arc \
        oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
        --namespace arc-systems \
        --create-namespace \
        --values ${toString controllerValues} --debug
    '')

    # ARC controller uninstall
    (pkgs.writeShellScriptBin "arc-uninstall" ''
      helm uninstall arc --namespace arc-systems || true
    '')

    # Runner sets install
    (pkgs.writeShellScriptBin "arc-runners-deploy" ''
      for file in ${toString runnerSetDir}/*.yaml; do
        name=$(basename "$file" .yaml)
        echo "Deploying runner set: $name"
        helm upgrade --install "$name" \
          oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
          --namespace arc-systems-runners \
          --create-namespace \
          --values "$file"
      done
    '')

    # Runner sets upgrade
    (pkgs.writeShellScriptBin "arc-runners-upgrade" ''
      arc-runners-deploy
    '')

    # Runner sets uninstall
    (pkgs.writeShellScriptBin "arc-runners-uninstall" ''
      for file in ${toString runnerSetDir}/*.yaml; do
        name=$(basename "$file" .yaml)
        echo "Uninstalling runner set: $name"
        helm uninstall "$name" --namespace arc-systems-runners || true
      done
    '')

    # Status checker
    (pkgs.writeShellScriptBin "arc-status" ''
      kubectl get pods -n arc-systems-runners
    '')

    # Status checker watch
    (pkgs.writeShellScriptBin "arc-status-watch" ''
      watch -n 2 kubectl get pods -n "arc-systems-runners"
    '')
  ];
}
