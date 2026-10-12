# Development Tools

Local development environment tools and wrappers for testing and development workflows.

## Act

Local GitHub Actions testing wrapper for running workflows on your machine.

### Prerequisites

- **Docker** or **Podman**
- **act** CLI - Install: `brew install act` or see [nektos/act](https://github.com/nektos/act). When it is missing, `run-ci-locally.sh` offers to install a pinned release after checking it against the release checksums.
- **Git** repository with GitHub Actions workflows

### Overview

Test GitHub Actions workflows locally before pushing to remote. The wrapper provides:
- Pre-configured runner with common development tools
- Event templates for different GitHub events (PR, push, tags)
- Local Docker registry support
- Artifact collection and analysis

A custom act-runner image is available at [`docker/utils/act-runner`](https://github.com/this-is-tobi/tools/tree/main/docker/utils/act-runner), pre-loaded with:
- **Cloud tools**: Scaleway CLI, Terraform, Ansible
- **Kubernetes**: kubectl, helm, kind, kustomize, argocd, argo, kyverno, kubescape
- **CI/CD**: GitHub CLI, trivy, cosign, ct (chart-testing)
- **Development**: Node.js, Python, Go, Rust, Bun (via mise)
- **Utilities**: Docker, jq, yq, sops, age, rclone, pandoc

> [!TIP]
> See complete tool list and build custom runner in `docker/utils/act-runner/Dockerfile`

### Setup

```sh
# Copy act directory to your project (creates ./act)
curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
  -u "https://github.com/this-is-tobi/tools" -b "main" -s "act" -o "."

cd act

# Registry credentials (only needed with -r): env/.env is git-ignored
cp env/.env-example env/.env
```

### Usage

```sh
# Run all workflows
./scripts/run-ci-locally.sh

# Run specific workflow
./scripts/run-ci-locally.sh -w ../.github/workflows/test.yml

# Use specific event template
./scripts/run-ci-locally.sh -e ./events/pr_base_main.json

# Start with local registry (127.0.0.1:5555, stopped when the run ends)
./scripts/run-ci-locally.sh -r

# Review artifacts
ls ./artifacts/$(date +%Y-%m-%d)/
```

Available event templates in `events/`:
- `pr_base_main.json` - Pull request to main
- `pr_draft.json` - Draft pull request
- `pr_not_draft.json` - Non-draft pull request
- `push_base_main.json` - Push to main branch
- `push_tag.json` - Tag push

### Configuration

**Custom runner** (`runners/Dockerfile`):
```dockerfile
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y python3 nodejs
```

**Local registry** (`env/.env`, copied from `env/.env-example`): `REGISTRY_USERNAME` and `REGISTRY_SECRET` have no default and the registry refuses to start without them. They can also come from the environment. The registry is published on `127.0.0.1` only, and the credentials reach `htpasswd` through stdin and `act` by variable name, so they never show in the process list. Generated files (`env/.env`, `registry/auth`, `registry/certs`, `registry/data`, `artifacts`) are git-ignored by `act/.gitignore`.

**Secrets** (`.secrets` file):
```sh
echo "MY_TOKEN=secret_value" > .secrets
act --secret-file .secrets
```

**Common flags** (`.actrc` file):
```
--secret-file=.secrets
--artifact-server-path=./artifacts
--container-architecture=linux/amd64
```

### Troubleshooting

**Docker permission denied:**
```sh
sudo usermod -aG docker $USER
newgrp docker
```

**Workflow not found:**
```sh
# Ensure .github/workflows/ exists
ls -la .github/workflows/

# List available workflows
act -l
```

**Runner image fails:**
```sh
# Rebuild custom runner
cd runners/
docker build -t act-runner:latest .
```

### Best Practices

- Use `.actrc` for common flags
- Cache dependencies in workflows
- Test with actual GitHub event payloads from `events/`
- Clean up artifacts regularly
- Pin runner versions for consistency

## Kind

Local Kubernetes development environment using Kubernetes in Docker.

### Prerequisites

- **Docker** or **Podman**
- **kind** - Install: `brew install kind` or see [kind.sigs.k8s.io](https://kind.sigs.k8s.io/docs/user/quick-start/#installation). When it is missing, `run.sh` offers to install a pinned release after checking its sha256.
- **kubectl** - Install: `brew install kubectl` or see [kubernetes.io](https://kubernetes.io/docs/tasks/tools/)
- **helm** (optional) - Install: `brew install helm`

### Overview

Run a local Kubernetes cluster for development and testing. The wrapper provides:
- Simplified cluster management
- Docker Compose integration for multi-image builds
- Pre-configured ingress controller (Traefik by default, or the retired ingress-nginx pinned to its last release)
- Volume mounting for live development
- Port forwarding to host machine

The cluster uses `extraMounts` to bind the host working directory to `/app` inside containers, enabling live code updates.

### Setup

```sh
# Copy kind directory to your project (creates ./kind)
curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
  -u "https://github.com/this-is-tobi/tools" -b "main" -s "kind" -o "."

cd kind
```

Configure `docker-compose.yml` with your application services.

### Usage

```sh
# Create cluster, build images, and deploy
./run.sh -c dev

# Step by step
./run.sh -c create    # Create cluster
./run.sh -c build     # Build and load images
./run.sh -c delete    # Cleanup cluster

# Use the retired ingress-nginx instead of Traefik
./run.sh -c create -i nginx

# Map local domains to 127.0.0.1 in /etc/hosts (sudo, missing names only)
./run.sh -c dev -d 'api.domain.local,doc.domain.local'

# View help
./run.sh -h

# Access application
kubectl get services
kubectl port-forward svc/myapp 8080:80
curl http://localhost/  # Via ingress
```

### Configuration

**Cluster configuration** (`configs/kind-config.yml`):
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      # The ingress controller service listens on these node ports
      - containerPort: 30080
        hostPort: 80
      - containerPort: 30443
        hostPort: 443
  - role: worker
```

**Images** (`docker-compose.yml`):
```yaml
services:
  api:
    build: ../api
    image: myapp/api:local
  frontend:
    build: ../frontend
    image: myapp/frontend:local
```

**Ingress controller**: `-i traefik` (default) or `-i nginx`. The [ingress-nginx project was retired in March 2026](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/) and gets no more releases or security fixes: `run.sh` pins it to its last release (`controller-v1.15.1`) for existing setups and prints a warning. Both controllers are exposed on node ports 30080/30443, mapped to the host ports 80/443.

### Troubleshooting

**Cluster creation fails:**
```sh
# Check Docker is running
docker ps

# Delete and recreate
kind delete cluster --name kind
./run.sh -c create
```

**Images not loading:**
```sh
# Verify image exists
docker images | grep myimage

# Load manually
kind load docker-image myimage:tag --name kind

# Check in cluster
docker exec -it kind-control-plane crictl images
```

**Cannot access ingress:**
```sh
# Check ingress controller status
kubectl get pods -n ingress-traefik  # or -n ingress-nginx
kubectl get ingress

# Test from within cluster
kubectl run test --rm -it --image=curlimages/curl -- curl http://myservice
```

**Port conflict:**
```sh
# Find process using port
lsof -i :80
lsof -i :443

# Change port mapping in configs/kind-config.yml
```

### Best Practices

- One cluster per project to avoid conflicts
- Version `kind-config.yml` in git
- Tag images as `local` to distinguish from registry images
- Use `imagePullPolicy: IfNotPresent` in manifests
- Set resource limits in manifests
- Clean up regularly: `kind delete cluster --name kind`
- Test with production-like configurations
