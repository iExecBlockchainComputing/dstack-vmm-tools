#!/bin/bash

# Install dstack auth-simple as a systemd service

set -e

DSTACK_DIR="${DSTACK_DIR:-/opt/dstack}"
AUTH_DIR="${DSTACK_DIR}/auth-simple"
AUTH_PORT="${AUTH_PORT:-3001}"
SERVICE_NAME="dstack-auth"
BUN_PATH="$(which bun 2>/dev/null || echo "/home/$(logname)/.bun/bin/bun")"
BUN_DIR="$(dirname "$BUN_PATH")"

if [ "$(id -u)" -ne 0 ]; then
  echo "error: this script must be run as root (sudo)."
  exit 1
fi

if [ ! -f "$BUN_PATH" ]; then
  echo "error: bun not found at $BUN_PATH. Install bun or set BUN_PATH."
  exit 1
fi

if [ ! -f "$AUTH_DIR/index.ts" ]; then
  echo "error: $AUTH_DIR/index.ts not found."
  exit 1
fi

if [ ! -f "$AUTH_DIR/auth-config.json" ]; then
  echo "error: $AUTH_DIR/auth-config.json not found."
  exit 1
fi

echo "Creating systemd service $SERVICE_NAME (port $AUTH_PORT)..."

cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=dstack auth-simple server
After=network.target

[Service]
Type=simple
WorkingDirectory=${AUTH_DIR}
Environment=PORT=${AUTH_PORT}
Environment=AUTH_CONFIG_PATH=${AUTH_DIR}/auth-config.json
Environment=PATH=${BUN_DIR}:/usr/local/bin:/usr/bin:/bin
ExecStart=${BUN_PATH} run start
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
