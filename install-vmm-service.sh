#!/bin/bash

# Install dstack-vmm as a systemd service

set -e

DSTACK_DIR="${DSTACK_DIR:-/opt/dstack}"
SERVICE_NAME="dstack-vmm"

if [ "$(id -u)" -ne 0 ]; then
  echo "error: this script must be run as root (sudo)."
  exit 1
fi

if [ ! -f "$DSTACK_DIR/dstack-vmm" ]; then
  echo "error: $DSTACK_DIR/dstack-vmm not found."
  exit 1
fi

if [ ! -f "$DSTACK_DIR/vmm.toml" ]; then
  echo "error: $DSTACK_DIR/vmm.toml not found."
  exit 1
fi

echo "Creating systemd service $SERVICE_NAME..."

cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=dstack VMM
After=network.target

[Service]
Type=simple
WorkingDirectory=${DSTACK_DIR}
ExecStart=${DSTACK_DIR}/dstack-vmm -c vmm.toml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ${SERVICE_NAME} && echo "dstack-vmm.service enabled NOW"
