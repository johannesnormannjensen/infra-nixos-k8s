# NixOS Kubernetes Cluster (K3s) – Flake-Based Setup

This repo provides a reproducible Kubernetes cluster setup using NixOS flakes and K3s, including integration with GitHub Actions Runner Controller (ARC).

## 🔧 Requirements

- NixOS installed on all nodes
- Flakes and `nix-command` enabled
- Each node should have its own `/etc/nixos/hardware-configuration.nix`
- A GitHub App created for ARC (with appropriate permissions)

## 📦 Included Roles

- `master.nix`: Configures the Kubernetes control plane (K3s server)
- `worker.nix`: Reusable configuration for all worker nodes using env variables
- `common.nix`: Shared system configuration (user, firewall, Docker, etc.)
- `modules/arc-tools.nix`: ARC deployment helpers
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

This assumes `/etc/nixos/hardware-configuration.nix` exists on the worker node.

```bash
export HOSTNAME=worker-general-1
export K3S_SERVER=https://<master-ip>:6443
export K3S_TOKEN=<your-token>
export K3S_NODE_LABELS="purpose=general"
export K3S_NODE_TAINTS=""

sudo nixos-rebuild switch --flake .#worker --impure
```

You can reuse the same worker.nix for as many nodes as you'd like.

### 3. GitHub CLI login (needed for ARC secrets)

Use one of the following to authenticate:

- **Via token**  
  ```bash
  gh auth login --with-token < ~/.ghtoken
  ```

- **Interactive**  
  ```bash
  gh auth login
  ```

To verify login:
```bash
gh auth status
```

## 🔐 Setting up ARC Secrets

To securely configure GitHub App credentials and registry access for ARC runners, follow these steps:

1. Copy the `.env` template:
   ```bash
   cp arc/secrets/.env.example arc/secrets/.env
   ```

2. Edit the `.env` file and fill in the required values:
   - `GITHUB_APP_ID`
   - `GITHUB_APP_INSTALLATION_ID`
   - `GITHUB_APP_PRIVATE_KEY_PATH`
   - `DOCKER_REGISTRY_SERVER`
   - `DOCKER_REGISTRY_USER`
   - `DOCKER_REGISTRY_PASSWORD`

if you want to use ghcr.io then the `DOCKER_REGISTRY_SERVER` should be `ghcr.io` and the `DOCKER_REGISTRY_USER` & `DOCKER_REGISTRY_PASSWORD` should be the GitHub username and it's personal access token with `read:packages` scope.

3. Load the variables into your shell session:
   ```bash
   source arc/secrets/.env
   ```

4. Run the helper script to create the secrets in your Kubernetes cluster:
   ```bash
   arc-secrets-create
   ```

To delete the secrets later:
```bash
arc-secrets-delete
```

### 📋 Commands

| Command               | Description                                                  |
|-----------------------|--------------------------------------------------------------|
| `cp arc/secrets/.env.example arc/secrets/.env` | Creates a working `.env` file from the template |
| `source arc/secrets/.env`       | Loads the environment variables into the current shell  |
| `arc-secrets-create`            | Creates Kubernetes secrets using the loaded variables   |
| `arc-secrets-delete`            | Deletes the ARC-related secrets from the cluster        |

### 🧠 Note

- `.env` is excluded from Git via `.gitignore`.
- `.env.example` is committed to provide a reference template.
- This approach allows secrets to be machine-local, reproducible, and not hardcoded.


## ⚙️ ARC Deploy & Control

Once secrets are in place, you can:

```bash
arc-deploy             # Installs/updates the ARC controller
arc-runners-deploy     # Installs runner sets from arc/runner-set/*.yaml
arc-runners-upgrade    # Re-applies values to all runner sets
arc-runners-uninstall  # Removes runner sets
arc-uninstall          # Uninstalls ARC controller
arc-status             # Shows ARC pods
```

## 📜 Available Commands

| Command               | Description                                       |
|-----------------------|---------------------------------------------------|
| `arc-deploy`          | Installs or upgrades ARC controller               |
| `arc-uninstall`       | Uninstalls ARC controller                         |
| `arc-runners-deploy`  | Deploys all runner sets in `arc/runner-set/`     |
| `arc-runners-upgrade` | Re-applies all runner sets                        |
| `arc-runners-uninstall` | Removes all runner sets                        |
| `arc-status`          | Shows pod status in `arc-system` namespace       |
| `arc-secrets-create`  | Creates GitHub App and Docker secrets from env   |

## 📁 Directory Structure

```
infra-nixos-k8s/
├── arc/
│   ├── controller/
│   ├── runner-set/
│   └── secrets/
├── hosts/
├── modules/
└── flake.nix
```

## 🧠 Notes

- The `--impure` flag is needed if you reference files outside the flake (e.g., `/etc/nixos/hardware-configuration.nix`)
- Helm version is pinned to avoid GUI/X11 dependency issues
- Labels and taints can be provided dynamically via env vars
