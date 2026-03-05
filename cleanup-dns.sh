#!/bin/bash

# Cleanup DNS records created by dstack-ingress for a given domain.
# By default runs in dry-run mode (shows what would be deleted).
# Use --confirm to actually delete.

set -e

usage() {
  echo "Usage: $0 --domain <domain> --cf-token <cloudflare-api-token> [--confirm]"
  echo ""
  echo "Options:"
  echo "  --domain    Domain to clean up (e.g. nox-kms.ovh-tdx-dev.noxprotocol.dev)"
  echo "  --cf-token  Cloudflare API token"
  echo "  --confirm   Actually delete records (without this flag, only shows what would be deleted)"
  echo ""
  echo "Records targeted (created by dstack-ingress):"
  echo "  - _dstack-app-address.<domain>  (TXT)"
  echo "  - <domain>                      (CNAME)"
  echo "  - <domain>                      (CAA)"
  exit 1
}

DOMAIN=""
CF_TOKEN=""
CONFIRM=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --cf-token) CF_TOKEN="$2"; shift 2 ;;
    --confirm) CONFIRM=true; shift ;;
    *) echo "error: unknown option $1"; usage ;;
  esac
done

if [ -z "$DOMAIN" ] || [ -z "$CF_TOKEN" ]; then
  echo "error: --domain and --cf-token are required."
  usage
fi

CF_API="https://api.cloudflare.com/client/v4"
AUTH_HEADER="Authorization: Bearer $CF_TOKEN"

# Extract the base zone from the domain (last 2 parts: e.g. noxprotocol.dev)
ZONE_NAME=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')

echo "Looking up zone: $ZONE_NAME"
ZONE_RESPONSE=$(curl -s -H "$AUTH_HEADER" "$CF_API/zones?name=$ZONE_NAME&status=active")
ZONE_ID=$(echo "$ZONE_RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['result'][0]['id'] if r['result'] else '')" 2>/dev/null)

if [ -z "$ZONE_ID" ]; then
  echo "error: could not find zone for $ZONE_NAME. Check your token permissions."
  exit 1
fi
echo "Zone ID: $ZONE_ID"
echo ""

# Define the records to look for
LOOKUPS=(
  "TXT:_dstack-app-address.${DOMAIN}"
  "CNAME:${DOMAIN}"
  "CAA:${DOMAIN}"
)

FOUND_RECORDS=()

for lookup in "${LOOKUPS[@]}"; do
  TYPE="${lookup%%:*}"
  NAME="${lookup#*:}"

  RESPONSE=$(curl -s -H "$AUTH_HEADER" "$CF_API/zones/$ZONE_ID/dns_records?type=$TYPE&name=$NAME")
  RECORDS=$(echo "$RESPONSE" | python3 -c "
import sys, json
r = json.load(sys.stdin)
for rec in r.get('result', []):
    print(f\"{rec['id']}|{rec['type']}|{rec['name']}|{rec['content']}\")
" 2>/dev/null)

  if [ -n "$RECORDS" ]; then
    while IFS= read -r line; do
      FOUND_RECORDS+=("$line")
      REC_ID=$(echo "$line" | cut -d'|' -f1)
      REC_TYPE=$(echo "$line" | cut -d'|' -f2)
      REC_NAME=$(echo "$line" | cut -d'|' -f3)
      REC_CONTENT=$(echo "$line" | cut -d'|' -f4)
      echo "  FOUND  $REC_TYPE  $REC_NAME  →  $REC_CONTENT"
    done <<< "$RECORDS"
  else
    echo "  -      $TYPE  $NAME  (not found)"
  fi
done

echo ""

if [ ${#FOUND_RECORDS[@]} -eq 0 ]; then
  echo "No dstack-ingress records found for $DOMAIN. Nothing to clean up."
  exit 0
fi

if [ "$CONFIRM" = false ]; then
  echo "DRY RUN: ${#FOUND_RECORDS[@]} record(s) would be deleted."
  echo "Re-run with --confirm to actually delete them."
  exit 0
fi

echo "Deleting ${#FOUND_RECORDS[@]} record(s)..."
for line in "${FOUND_RECORDS[@]}"; do
  REC_ID=$(echo "$line" | cut -d'|' -f1)
  REC_TYPE=$(echo "$line" | cut -d'|' -f2)
  REC_NAME=$(echo "$line" | cut -d'|' -f3)

  DEL_RESPONSE=$(curl -s -X DELETE -H "$AUTH_HEADER" "$CF_API/zones/$ZONE_ID/dns_records/$REC_ID")
  SUCCESS=$(echo "$DEL_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success','false'))" 2>/dev/null)

  if [ "$SUCCESS" = "True" ] || [ "$SUCCESS" = "true" ]; then
    echo "  ✓ deleted $REC_TYPE $REC_NAME"
  else
    echo "  ✗ failed to delete $REC_TYPE $REC_NAME (id: $REC_ID)"
  fi
done

echo ""
echo "Done."
