#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <GITHUB_APP_ID> <GITHUB_APP_INSTALLATION_ID> <GITHUB_APP_PRIVATE_KEY_PATH> <ORG_REPO (org/repo)>"
  exit 1
fi

APP_ID="$1"
INSTALLATION_ID="$2"
PRIVATE_KEY_PATH="$3"
ORG_REPO="$4"

if [ ! -f "$PRIVATE_KEY_PATH" ]; then
  echo "❌ Private key file not found: $PRIVATE_KEY_PATH"
  exit 1
fi

# Generate JWT (expires after 9 minutes)
iat=$(date +%s)
exp=$((iat + 540))

header_base64=$(printf '{"alg":"RS256","typ":"JWT"}' | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')
payload_base64=$(printf '{"iat":%s,"exp":%s,"iss":"%s"}' "$iat" "$exp" "$APP_ID" | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')
unsigned_token="$header_base64.$payload_base64"

signature=$(printf %s "$unsigned_token" | openssl dgst -sha256 -sign "$PRIVATE_KEY_PATH" | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')
jwt="$unsigned_token.$signature"

echo "📥 Requesting installation access token..."
access_token=$(curl -s -X POST \
  -H "Authorization: Bearer $jwt" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/$INSTALLATION_ID/access_tokens" | jq -r .token)

echo "🔧 Getting runner registration token for $ORG_REPO..."
curl -s -X POST \
  -H "Authorization: token $access_token" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$ORG_REPO/actions/runners/registration-token" | jq
