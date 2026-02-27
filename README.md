# dstack-vmm-tools

CLI tools for deploying and monitoring Confidential VMs (CVMs) on [dstack-vmm](https://github.com/aspect-build/dstack).

## Prerequisites

- Python 3.8+
- `jq`
- A running `dstack-vmm` instance
- A running `dstack-kms` instance

## Tools

### `deployer.sh` — Deploy a CVM

Handles the full CVM app deployment:

1. Loads configuration from `.env` (creates a template on first run)
2. Generates a pre-launch script (token verification + optional Docker login)
3. Builds `app-compose.json` from your `docker-compose.yaml`
4. Injects `launch_token_hash` for security verification
5. Deploys the CVM to dstack-vmm

#### Quick start

```bash
# 1. Create your app directory with a docker-compose.yaml
mkdir my-app && cd my-app
cat > docker-compose.yaml <<EOF
services:
  my-service:
    image: my-image:latest
    ports:
      - "8080:80"
EOF

# 2. Run the deploy script (first run creates a .env template)
/path/to/dstack-vmm-tools/deployer.sh

# 3. Edit the generated .env file with your values
vim .env

# 4. Run the deploy script again
/path/to/dstack-vmm-tools/deployer.sh
```

#### Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `APP_NAME` | ✅ | Name of the app |
| `APP_ID` | ✅ | App ID. For on-chain governance: the app smart contract address. For off-chain: a random hex string (e.g. `openssl rand -hex 20`) |
| `VMM_RPC` | ✅ | URL of the dstack-vmm RPC service |
| `KMS_URL` | ✅ | URL of the KMS service |
| `OS_IMAGE` | ✅ | dstack OS image name (e.g. `dstack-0.5.6`) |
| `APP_LAUNCH_TOKEN` | ✅ | Token for app launch verification (auto-generated in template) |
| `GUEST_AGENT_ADDR` | ❌ | Host address for guest agent (e.g. `127.0.0.1:9205`) |
| `DOCKER_REGISTRY` | ❌ | Docker registry URL (e.g. `docker-regis.iex.ec`). All three `DOCKER_*` must be set together |
| `DOCKER_USER` | ❌ | Docker registry username |
| `DOCKER_TOKEN` | ❌ | Docker registry token |
| `CLOUDFLARE_API_TOKEN` | ❌ | Cloudflare API token for DNS-01 challenge (used by `dstack-ingress`) |
| `VCPU` | ❌ | Number of vCPUs (default: `2`) |
| `MEMORY` | ❌ | Memory size (default: `2G`) |
| `DISK` | ❌ | Disk size (default: `20G`) |
| `NET_MODE` | ❌ | Networking mode: `user` (default) or `bridge` |
| `PORT_MAP` | ❌ | Space-separated port mappings (format: `protocol[:address]:host_port:vm_port`) |

#### Generated files

| File | Description |
|------|-------------|
| `.env` | Configuration template (created on first run) |
| `.app_env` | Environment secrets injected into the CVM |
| `.app-compose.json` | App compose manifest sent to dstack-vmm |

### `monitor.sh` — Stream CVM logs

Streams logs from a running CVM container via the Gateway:

```bash
./dstack-vmm-tools/monitor.sh \
  --app-id 4139fa786b4e210cecbb37d62d86552fc659fbc8 \
  --agent-port 8090 \
  --gateway-url apps.ovh-tdx-dev.noxprotocol.dev \
  --container nox-kms
```

| Option | Required | Description |
|--------|----------|-------------|
| `--app-id` | ✅ | App ID of the CVM |
| `--agent-port` | ✅ | Guest agent port |
| `--gateway-url` | ✅ | Gateway base URL (e.g. `apps.ovh-tdx-dev.noxprotocol.dev`) |
| `--container` | ✅ | Container name to fetch logs from |
