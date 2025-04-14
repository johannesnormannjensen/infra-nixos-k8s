# 🚀 NixOS Kubernetes Cluster (K3s) – Flake-Based Setup

This repo provides a reproducible and modular Kubernetes cluster setup using [NixOS flakes](https://nixos.wiki/wiki/Flakes) and [K3s](https://k3s.io/), along with GitHub Actions Runner Controller (ARC).

---

## 🔧 Requirements

- NixOS installed on all nodes
- `flakes` and `nix-command` enabled (included via `common.nix`)
- Each node should have its own `/etc/nixos/hardware-configuration.nix`
- Internet access to pull Helm charts and Docker images

---

## 📦 Structure & Roles

| File/Folder              | Purpose |
|--------------------------|---------|
| `flake.nix`              | Top-level flake entrypoint |
| `hosts/master.nix`       | Master node setup (K3s server, ARC tools) |
| `hosts/worker.nix`       | Worker node template (dynamic via env vars) |
| `hosts/common.nix`       | Shared config (users, SSH, Docker, etc.) |
| `modules/arc-tools.nix`  | Declarative Helm install tools for ARC |
| `arc/`                   | ARC controller values and runner set YAMLs |

---

## 🖥️ Master Node Setup

1. Ensure `hardware-configuration.nix` is present:

```bash
ls /etc/nixos/hardware-configuration.nix
```

2. Deploy the master node:

```bash
sudo nixos-rebuild switch --flake .#master
```

3. Check the status of K3s:

```bash
kubectl get nodes
```

4. Retrieve token to join worker nodes:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

## 👷 Worker Nodes Setup

You can reuse the same flake config for all workers. Just set environment variables per node:

```bash
export HOSTNAME=worker-general-1
export K3S_SERVER=https://<master-ip>:6443
export K3S_TOKEN=<your-token>
export K3S_NODE_LABELS="purpose=general"
export K3S_NODE_TAINTS=""

sudo nixos-rebuild switch --flake .#worker
```

This allows dynamic, reproducible deployments across many machines of the same type.

## 🛠️ ARC CLI Tools

ARC-related CLI tools are declared in modules/arc-tools.nix and included only on the master node. Once deployed, the following tools are available system-wide:


| Command | Description |
|---------------------------|-----------------------------------|
| `arc-deploy`              | Installs ARC controller via Helm  |
| `arc-uninstall`           | Uninstalls ARC controller         |
| `arc-runners-deploy`      | Installs all runner sets (from arc/runner-set/*.yaml) |
| `arc-runners-upgrade`     | Re-applies runner set configs     |
| `arc-runners-uninstall`   | Removes all runner sets           |
| `arc-status`              | Displays runner pods in the arc-systems namespace       |
| `arc-status-watch`        | Watches the status of runner pods in the arc-systems namespace |


## ⚙️ Auto kubeconfig (kubectl ready out-of-the-box)

To avoid having to set the KUBECONFIG environment variable manually:

```nix
environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
```
This is part of common.nix and ensures kubectl just works after login.

## 📝 Notes
- The --impure flag is no longer needed after correcting relative paths to ARC files.
- You can override per-node behavior (e.g., taints, labels, etc.) using builtins.getEnv in the worker flake config.
- Worker nodes can be cloned and added rapidly if they share hardware and config.
- Master node includes ARC only to reduce complexity and avoid unnecessary Helm dependencies on workers.

## 📍 Future Ideas
- Use SOPS or Sealed Secrets for secrets management
- Add metrics (Prometheus/Grafana stack)
- Enable PXE or USB netboot with automatic flake-based provisioning
- Integrate backup/restore of cluster state
