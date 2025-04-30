{ pkgs, ... }:

let
  controllerValues = ./../arc/controller/values.yaml;
  runnerSetDir = ./../arc/runner-set;
in {
  environment.systemPackages = with pkgs; [

    # ARC controller install
    (pkgs.writeShellScriptBin "deploy-arc-controller" ''
      helm upgrade --install arc \
        oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
        --namespace arc-systems \
        --create-namespace \
        --reset-values \
        --values ${toString controllerValues} --debug
    '')

    # ARC controller uninstall
    (pkgs.writeShellScriptBin "uninstall-arc-controller" ''
      helm uninstall arc --namespace arc-systems || true
    '')

    # Runner sets install
    (pkgs.writeShellScriptBin "deploy-arc-runners" ''
      for file in ${toString runnerSetDir}/*.yaml; do
        name=$(basename "$file" .yaml)
        echo "Deploying runner set: $name"
        helm upgrade --install "$name" \
          oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
          --namespace arc-systems-runners \
          --create-namespace \
          --reset-values \
          --values "$file"
      done
    '')

    # Runner sets upgrade
    (pkgs.writeShellScriptBin "upgrade-arc-runners" ''
      deploy-arc-runners
    '')

    # Runner sets uninstall
    (pkgs.writeShellScriptBin "uninstall-arc-runners" ''
      for file in ${toString runnerSetDir}/*.yaml; do
        name=$(basename "$file" .yaml)
        echo "Uninstalling runner set: $name"
        helm uninstall "$name" --namespace arc-systems-runners || true
      done
    '')

    # Status checker
    (pkgs.writeShellScriptBin "status-arc-runners" ''
      kubectl get pods -n arc-systems-runners
    '')

    # Status checker watch
    (pkgs.writeShellScriptBin "status-arc-runners-watch" ''
      watch -n 2 kubectl get pods -n "arc-systems-runners"
    '')
  ];
}
