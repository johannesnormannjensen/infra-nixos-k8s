{ pkgs, lib, inputs }:

{
  arc-controller = {
    name = "arc";
    chart = "gha-runner-scale-set-controller";
    repo = "oci://ghcr.io/actions/actions-runner-controller-charts";
    version = "0.11.0";
    namespace = "custom-arc-systems";
    values = ./../arc/controller/values.yaml;
  };
}
