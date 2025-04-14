# NixOS Kubernetes Cluster (K3s) – Flake-Based Setup

This repo provides a reproducible Kubernetes cluster setup using NixOS flakes and K3s.

## 🔧 Requirements

- NixOS installed on all nodes
- Flakes and `nix-command` enabled
- Each node should have its own `/etc/nixos/hardware-configuration.nix`

## 📦 Included Roles

- `master.nix`: Configures the Kubernetes control plane (K3s server)
- `worker.nix`: Reusable configuration for all worker nodes using env variables
- `common.nix`: Shared system configuration (user, firewall, Docker, etc.)

## 🖥️ Setup Instructions

### 1. Master Node

```bash
sudo nixos-rebuild switch --flake .#master --impure
```

This assumes /etc/nixos/hardware-configuration.nix exists on the master node.

To get the K3s token (needed for workers):

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

### 2. Worker Nodes
Export required environment variables and run:

```bash
export HOSTNAME=worker1
export K3S_SERVER=https://<master-ip>:6443
export K3S_TOKEN=<token-from-master>

sudo nixos-rebuild switch --flake .#worker --impure
```
You can reuse the same worker.nix for as many nodes as you'd like.

🧪 Verify the cluster
On the master node:
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```
You should see all joined nodes listed.

🧠 Notes
 - The --impure flag is required since we refer to files outside the flake (e.g., hardware config).

 - You can override more via builtins.getEnv (e.g. labels, taints, etc.)

 - For clusters with varied hardware, consider dedicated workerN.nix configs.