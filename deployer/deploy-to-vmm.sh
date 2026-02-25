#!/bin/bash

# Deploy an app CVM to dstack-vmm

set -e

# Check if .env exists
if [ -f ".env" ]; then
  echo "Loading environment variables from .env file..."
  set -a
  source .env
  set +a
else
  # Create a template .env file
  echo "Creating template .env file..."
  cat >.env <<EOF
# Required environment variables for CVM app deployment

# Name of the app (used for --name in compose and deploy)
APP_NAME=

# The URL of the dstack-vmm RPC service
VMM_RPC=http://127.0.0.1:9080

# KMS URL (the KMS must be running and accessible)
KMS_URL=https://kms.ovh-tdx-dev.noxconfidential.dev:9201

# App ID (from on-chain governance: npx hardhat kms:create-app)
# APP_ID=


# The address of the guest agent service listening on Host machine (optional)
# GUEST_AGENT_ADDR=127.0.0.1:9205

# Docker private registry (optional, required only for private images)
# DOCKER_REGISTRY=docker-regis.iex.ec
# DOCKER_USER=
# DOCKER_TOKEN=

# The token used to launch the App
APP_LAUNCH_TOKEN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# dstack OS image name
OS_IMAGE=dstack-0.5.6

# Number of vCPUs
VCPU=2

# Memory size
MEMORY=2G

# Disk size
DISK=20G

# Networking mode: "user" (default) or "bridge"
# NET_MODE=user

# Port mappings from host to CVM (space-separated)
# Format: protocol[:address]:host_port:vm_port
# Example: PORT_MAP="tcp:0.0.0.0:8080:80 tcp:127.0.0.1:9443:443"
# PORT_MAP=
EOF
  echo "Please edit the .env file and set the required variables, then run this script again."
  exit 1
fi

required_env_vars=(
  "APP_NAME"
  "VMM_RPC"
  "KMS_URL"
  "OS_IMAGE"
  "APP_LAUNCH_TOKEN"
)

for var in "${required_env_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Error: required environment variable $var is not set."
    echo "Please edit the .env file and set a value for $var, then run this script again."
    exit 1
  fi
done

# Write env file with secrets for the CVM
[ -s .app_env ] && [ -n "$(tail -c 1 .app_env)" ] && echo >> .app_env
echo "APP_LAUNCH_TOKEN=$APP_LAUNCH_TOKEN" >> .app_env

if [ -n "$DOCKER_TOKEN" ] || [ -n "$DOCKER_REGISTRY" ] || [ -n "$DOCKER_USER" ]; then
  if [ -z "$DOCKER_TOKEN" ] || [ -z "$DOCKER_REGISTRY" ] || [ -z "$DOCKER_USER" ]; then
    echo "Error: DOCKER_REGISTRY, DOCKER_USER and DOCKER_TOKEN must all be set together."
    exit 1
  fi
  echo "DOCKER_REGISTRY=$DOCKER_REGISTRY" >> .app_env
  echo "DOCKER_USER=$DOCKER_USER" >> .app_env
  echo "DOCKER_TOKEN=$DOCKER_TOKEN" >> .app_env
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$SCRIPT_DIR/../vmm-cli.py --url $VMM_RPC"

EXPECTED_TOKEN_HASH=$(echo -n "$APP_LAUNCH_TOKEN" | sha256sum | cut -d' ' -f1)

# Create pre-launch script for launch token verification
cat >.prelaunch.sh <<'EOF'
EXPECTED_TOKEN_HASH=$(jq -j .launch_token_hash app-compose.json)
if [ "$EXPECTED_TOKEN_HASH" == "null" ]; then
    echo "Skipped APP_LAUNCH_TOKEN check"
else
  ACTUAL_TOKEN_HASH=$(echo -n "$APP_LAUNCH_TOKEN" | sha256sum | cut -d' ' -f1)
  if [ "$EXPECTED_TOKEN_HASH" != "$ACTUAL_TOKEN_HASH" ]; then
      echo "Error: Incorrect APP_LAUNCH_TOKEN, please make sure set the correct APP_LAUNCH_TOKEN in env"
      reboot
      exit 1
  else
      echo "APP_LAUNCH_TOKEN checked OK"
  fi
fi

if [ -n "$DOCKER_TOKEN" ] && [ -n "$DOCKER_REGISTRY" ] && [ -n "$DOCKER_USER" ]; then
  echo "$DOCKER_TOKEN" | docker login "$DOCKER_REGISTRY" -u "$DOCKER_USER" --password-stdin
fi
EOF

echo "Generating app-compose.json..."

$CLI compose \
  --docker-compose docker-compose.yaml \
  --name "$APP_NAME" \
  --kms \
  --gateway \
  --env-file .app_env \
  --public-logs \
  --public-sysinfo \
  --prelaunch-script .prelaunch.sh \
  --output .app-compose.json \
  > /dev/null

rm -f .prelaunch.sh

# Inject launch_token_hash and public_tcbinfo into app-compose.json
mv .app-compose.json .app-compose.json.tmp
jq \
  --arg token_hash "$EXPECTED_TOKEN_HASH" \
  '.launch_token_hash = $token_hash | .public_tcbinfo = true' \
  .app-compose.json.tmp > .app-compose.json
rm -f .app-compose.json.tmp

COMPOSE_HASH=$(sha256sum .app-compose.json | cut -d' ' -f1)
echo "Compose hash: 0x$COMPOSE_HASH"

echo ""
echo "Configuration:"
echo "  APP_NAME: $APP_NAME"
echo "  VMM_RPC: $VMM_RPC"
echo "  KMS_URL: $KMS_URL"
if [ -n "$APP_ID" ]; then
  echo "  APP_ID: $APP_ID"
fi
if [ -n "$APP_ADDR" ]; then
  echo "  APP_ADDR: $APP_ADDR"
fi
if [ -n "$GUEST_AGENT_ADDR" ]; then
  echo "  GUEST_AGENT_ADDR: $GUEST_AGENT_ADDR"
fi
echo "  OS_IMAGE: ${OS_IMAGE:-dstack-0.5.6}"
echo "  VCPU: ${VCPU:-2}"
echo "  MEMORY: ${MEMORY:-2G}"
echo "  DISK: ${DISK:-20G}"
if [ -n "$PORT_MAP" ]; then
  echo "  PORT_MAP: $PORT_MAP"
fi
if [ -n "$NET_MODE" ]; then
  echo "  NET_MODE: $NET_MODE"
fi
echo ""

if [ -t 0 ]; then
  read -p "Continue? [y/N] " -n 1 -r
  echo

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 1
  fi
fi

echo "Deploying $APP_NAME to dstack-vmm..."

DEPLOY_ARGS=(
  --name "$APP_NAME"
  --compose .app-compose.json
  --env-file .app_env
  --kms-url "$KMS_URL"
  --image "$OS_IMAGE"
  --vcpu "${VCPU:-2}"
  --memory "${MEMORY:-2G}"
  --disk "${DISK:-20G}"
)

# App ID is optional — needed for on-chain governance
if [ -n "$APP_ID" ]; then
  DEPLOY_ARGS+=(--app-id "$APP_ID")
fi

if [ -n "$GUEST_AGENT_ADDR" ]; then
  DEPLOY_ARGS+=(--port "tcp:$GUEST_AGENT_ADDR:8090")
fi

if [ -n "$PORT_MAP" ]; then
  for pm in $PORT_MAP; do
    DEPLOY_ARGS+=(--port "$pm")
  done
fi

if [ -n "$NET_MODE" ]; then
  DEPLOY_ARGS+=(--net "$NET_MODE")
fi

$CLI deploy "${DEPLOY_ARGS[@]}"

echo ""
echo "$APP_NAME deployed successfully!"
echo ""
echo "Compose hash: 0x$COMPOSE_HASH"
echo "If using on-chain governance, whitelist this hash with:"
echo "  npx hardhat app:add-hash --hash 0x$COMPOSE_HASH --network <network>"
