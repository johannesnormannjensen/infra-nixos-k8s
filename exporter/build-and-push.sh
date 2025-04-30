#!/usr/bin/env bash
set -euo pipefail

# Usage help
function usage() {
  echo "Usage: $0 <registry> <image-name> <tag> [docker-username] [docker-password]"
  echo
  echo "Arguments:"
  echo "  registry         Docker registry (e.g., ghcr.io, registry.example.com)"
  echo "  image-name       Name of the Docker image (e.g., github-metrics-exporter)"
  echo "  tag              Image tag (e.g., latest, v1.0.0)"
  echo "Optional:"
  echo "  docker-username  Username for Docker login (if required)"
  echo "  docker-password  Password for Docker login (if required)"
  exit 1
}

# Check arguments
if [ "$#" -lt 3 ]; then
  usage
fi

REGISTRY="$1"
IMAGE_NAME="$2"
TAG="$3"
USERNAME="${4:-}"
PASSWORD="${5:-}"

FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "[+] Building Docker image: ${FULL_IMAGE_NAME}"
docker build -t "${FULL_IMAGE_NAME}" .

if [[ -n "${USERNAME}" && -n "${PASSWORD}" ]]; then
  echo "[+] Logging in to Docker registry: ${REGISTRY}"
  echo "${PASSWORD}" | docker login "${REGISTRY}" --username "${USERNAME}" --password-stdin
fi

echo "[+] Pushing image to ${FULL_IMAGE_NAME}"
docker push "${FULL_IMAGE_NAME}"

echo "[+] Build and push complete!"
