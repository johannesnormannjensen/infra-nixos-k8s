#!/bin/bash
set -e
SCRIPT_DIR=$(dirname "$(realpath "$0")")

echo "🔐 Creating/updating secrets..."
$SCRIPT_DIR/secrets/create.sh || echo "⚠️ Secrets already exist"

echo "🧠 Installing/upgrading controller..."
$SCRIPT_DIR/controller/install.sh

echo "⚙️ Installing/upgrading runner sets..."
$SCRIPT_DIR/runner-set/install.sh

echo "✅ ARC system is up to date."