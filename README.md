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
- `arc-tools.nix`: Installs runner controller and runner sets  
- `arc-secrets.nix`: Provides CLI tools to manage ARC secrets  

## 🖥️ Setup Instructions

### 1. Master Node

```bash
sudo nixos-rebuild switch --flake .#master --impure
```

This assumes `/etc/nixos/hardware-configuration.nix` exists on the master node.

To get the K3s token (needed for workers):

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

### 2. Worker Nodes

Create a hardware config (e.g. `/etc/nixos/hardware-configuration.nix`) on the worker node. Then run:

```bash
export HOSTNAME=worker-general-1
export K3S_SERVER=https://<master-ip>:6443
export K3S_TOKEN=<your-token>
export K3S_NODE_LABELS="purpose=general"
export K3S_NODE_TAINTS=""

sudo nixos-rebuild switch --flake .#worker --impure
```

You can reuse the same `worker.nix` for as many nodes as you'd like.

## 🧪 Verifying cluster

On the master node:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

You should see all joined nodes listed.

## ⚙️ Automatic kubeconfig for kubectl

To avoid having to set the `KUBECONFIG` variable manually, the following is included in `common.nix`:

```nix
environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
```

This makes the kubeconfig available automatically for the kubectl command after login.  
It is especially useful on the master node.

## ⚒️ ARC Controller + Runner Installation

| Command               | Description                                           |
|-----------------------|-------------------------------------------------------|
| `arc-deploy`          | Installs or upgrades the ARC controller               |
| `arc-uninstall`       | Uninstalls the ARC controller                         |
| `arc-runners-deploy`  | Installs all runner sets in `arc/runner-set/`         |
| `arc-runners-upgrade` | Upgrades all runner sets                              |
| `arc-runners-uninstall` | Uninstalls all runner sets                         |
| `arc-status`          | Shows pod status for namespace `arc-system`           |

## 🔐 Authenticating GitHub CLI (gh)

You must authenticate the GitHub CLI to be able to interact with the GitHub Container Registry (`ghcr.io`) and generate tokens for ARC secrets.

You can authenticate in two ways:

### Option 1: Interactive Login

```bash
gh auth login
```

Choose:
- GitHub.com
- HTTPS
- Login with a web browser (follow the instructions)

### Option 2: Login with token

Generate a personal access token (PAT) with `read:org`, `repo`, `write:packages`, and `admin:org` scopes.

```bash
gh auth login --with-token < ~/.ghtoken
```

## 🔐 Managing GitHub App Secrets

1. Store your private key on the master node (do not version control):

```
/etc/secrets/gh-app-private-key.pem
```

2. Export these environment variables before running the secrets command:

```bash
export GITHUB_APP_ID=your-app-id
export GITHUB_APP_INSTALLATION_ID=your-installation-id
export GITHUB_DOCKER_USERNAME=username-gh-login
```

3. Create the secrets:

```bash
arc-secrets-create
```

This sets up:
- `runnersecret`: a Docker registry secret for `ghcr.io`
- `pre-defined-secret`: a secret containing your GitHub App credentials

## 🧠 Notes

- The `--impure` flag is required if hardware-configuration.nix is imported from `/etc`.
- You can override more via `builtins.getEnv` (e.g. labels, taints).
- For clusters with varied hardware, consider dedicated `workerN.nix` configs.
