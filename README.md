# dstack-vmm-tools

CLI tools for deploying Confidential VMs (CVMs) on [dstack-vmm](https://github.com/aspect-build/dstack).

## Prerequisites

- Python 3.8+
- `jq`
- A running `dstack-vmm` instance
- A running `dstack-kms` instance

## Quick start

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
/path/to/dstack-vmm-tools/deployer/deploy-to-vmm.sh

# 3. Edit the generated .env file with your values
vim .env

# 4. Run the deploy script again
/path/to/dstack-vmm-tools/deployer/deploy-to-vmm.sh
```

## Deployment workflow

The `deployer/deploy-to-vmm.sh` script handles the full CVM app deployment:

1. Loads configuration from `.env` (creates a template on first run)
2. Generates a pre-launch script (token verification + optional Docker login)
3. Builds `app-compose.json` from your `docker-compose.yaml`
4. Injects `launch_token_hash` for security verification
5. Deploys the CVM to dstack-vmm

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `APP_NAME` | ✅ | Name of the app |
| `VMM_RPC` | ✅ | URL of the dstack-vmm RPC service |
| `KMS_URL` | ✅ | URL of the KMS service |
| `OS_IMAGE` | ✅ | dstack OS image name (e.g. `dstack-0.5.6`) |
| `APP_LAUNCH_TOKEN` | ✅ | Token for app launch verification (auto-generated in template) |
| `APP_ID` | ❌ | App ID for identification. If not set, a random ID is derived from the compose hash — set it explicitly if you need a stable ID |
| `GUEST_AGENT_ADDR` | ❌ | Host address for guest agent (e.g. `127.0.0.1:9205`) |
| `DOCKER_REGISTRY` | ❌ | Docker registry URL (e.g. `docker-regis.iex.ec`). Required if `DOCKER_TOKEN` is set |
| `DOCKER_USER` | ❌ | Docker registry username. Required if `DOCKER_TOKEN` is set |
| `DOCKER_TOKEN` | ❌ | Docker registry token. All three `DOCKER_*` variables must be set to pull from a private registry |
| `VCPU` | ❌ | Number of vCPUs (default: `2`) |
| `MEMORY` | ❌ | Memory size (default: `2G`) |
| `DISK` | ❌ | Disk size (default: `20G`) |
| `NET_MODE` | ❌ | Networking mode: `user` (default) or `bridge` |
| `PORT_MAP` | ❌ | Space-separated port mappings between CVM and host (format: `protocol[:address]:host_port:vm_port`) |

## Generated files

| File | Description |
|------|-------------|
| `.env` | Configuration template (created on first run) |
| `.app_env` | Environment secrets injected into the CVM |
| `.app-compose.json` | App compose manifest sent to dstack-vmm |
