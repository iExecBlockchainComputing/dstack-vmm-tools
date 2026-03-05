#!/bin/bash

# Stream logs from a CVM container via the Gateway

set -e

usage() {
  echo "Usage: $0 --app-id <appId> --agent-port <port> --gateway-url <url> --container <name>"
  echo ""
  echo "Options:"
  echo "  --app-id        App ID of the CVM"
  echo "  --agent-port    Guest agent port"
  echo "  --gateway-url   Gateway base URL (e.g. apps.ovh-tdx-dev.noxprotocol.dev)"
  echo "  --container     Container name to fetch logs from"
  echo "  -h, --help      Show this help message"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-id)
      APP_ID="$2"
      shift 2
      ;;
    --agent-port)
      AGENT_PORT="$2"
      shift 2
      ;;
    --gateway-url)
      GATEWAY_URL="$2"
      shift 2
      ;;
    --container)
      CONTAINER="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "error: unknown option: $1"
      usage
      ;;
  esac
done

if [ -z "$APP_ID" ] || [ -z "$AGENT_PORT" ] || [ -z "$GATEWAY_URL" ] || [ -z "$CONTAINER" ]; then
  echo "error: --app-id, --agent-port, --gateway-url and --container are all required."
  echo ""
  usage
fi

URL="https://${APP_ID}-${AGENT_PORT}.${GATEWAY_URL}/logs/${CONTAINER}?follow=true&text=true&timestamps=true&bare=true"

echo "Streaming logs from ${CONTAINER} (app: ${APP_ID})..."
echo "URL: ${URL}"
echo "---"

curl -sN "$URL"
