{ pkgs, ... }:

let
  NAMESPACE = "arc-systems-runners";

  secretCreate = pkgs.writeShellScriptBin "arc-secrets-create" ''
    set -euo pipefail

    # Load environment
    if [ -f ./arc/secrets/.env ]; then
      echo "📥 Sourcing environment from .env"
      set -a
      source ./arc/secrets/.env
      set +a
    else
      echo "❌ .env file not found in arc/secrets/.env"
      exit 1
    fi

    if [ ! -f "$GITHUB_APP_PRIVATE_KEY_PATH" ]; then
      echo "❌ Private key not found at $GITHUB_APP_PRIVATE_KEY_PATH"
      exit 1
    fi

    if [ -z "''${GITHUB_APP_ID:-}" ]; then
      echo "❌ Please set GITHUB_APP_ID in .env"
      exit 1
    fi

    if [ -z "''${GITHUB_APP_INSTALLATION_ID:-}" ]; then
      echo "❌ Please set GITHUB_APP_INSTALLATION_ID in .env"
      exit 1
    fi

    echo "📦 Reading private key and generating GitHub token..."
    CR_PAT=$(gh auth token)
    GITHUB_APP_PRIVATE_KEY=$(cat "$GITHUB_APP_PRIVATE_KEY_PATH")

    echo "🔐 Creating namespace '${NAMESPACE}' if needed..."
    kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

    if [ -n "''${DOCKER_REGISTRY_SERVER:-}" ] && [ -n "''${DOCKER_REGISTRY_USER:-}" ] && [ -n "''${DOCKER_REGISTRY_PASSWORD:-}" ]; then
      echo "🔐 Creating runner docker-registry secret..."
      kubectl create secret docker-registry runnersecret \
        --namespace "${NAMESPACE}" \
        --docker-server="$DOCKER_REGISTRY_SERVER" \
        --docker-username="$DOCKER_REGISTRY_USER" \
        --docker-password="$DOCKER_REGISTRY_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -
    else
      echo "ℹ️ Docker registry credentials not set – skipping runnersecret. Set DOCKER_* in .env to enable."
    fi

    echo "🔐 Creating pre-defined GitHub App secret..."
    kubectl create secret generic pre-defined-secret \
      --namespace "${NAMESPACE}" \
      --from-literal=github_app_id="$GITHUB_APP_ID" \
      --from-literal=github_app_installation_id="$GITHUB_APP_INSTALLATION_ID" \
      --from-literal=github_app_private_key="$GITHUB_APP_PRIVATE_KEY" \
      --dry-run=client -o yaml | kubectl apply -f -

    echo "✅ ARC secrets created successfully."
  '';

  secretDelete = pkgs.writeShellScriptBin "arc-secrets-delete" ''
    set -euo pipefail

    FORCE="false"
    if [ "''${1:-}" = "--force" ]; then
      FORCE="true"
    fi

    if [ "$FORCE" != "true" ]; then
      echo "⚠️ This will delete the following secrets in namespace '${NAMESPACE}':"
      echo " - runnersecret (if it exists)"
      echo " - pre-defined-secret"
      echo ""
      read -p "Are you sure? (type 'yes' to continue): " CONFIRM
      if [ "$CONFIRM" != "yes" ]; then
        echo "❌ Aborted."
        exit 1
      fi
    fi

    echo "🧨 Deleting secrets from namespace '${NAMESPACE}'..."
    kubectl delete secret runnersecret --namespace "${NAMESPACE}" || true
    kubectl delete secret pre-defined-secret --namespace "${NAMESPACE}" || true
    echo "✅ Secrets deleted."
  '';
in {
  environment.systemPackages = [
    secretCreate
    secretDelete
  ];
}
