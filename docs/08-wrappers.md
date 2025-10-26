# Development Tools

Local development environment tools and wrappers for testing and development workflows.

## Act

Local GitHub Actions testing wrapper for running workflows on your machine.

### Prerequisites

- **Docker** or **Podman**
- **act** CLI - Install: `curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash`
- **Git** repository with GitHub Actions workflows

### Overview

Test GitHub Actions workflows locally before pushing to remote. The wrapper provides:
- Pre-configured runner with common development tools
- Event templates for different GitHub events (PR, push, tags)
- Local Docker registry support
- Artifact collection and analysis

A custom act-runner image is available at [`docker/utils/act-runner`](https://github.com/this-is-tobi/tools/tree/main/docker/utils/act-runner), pre-loaded with:
- **Cloud tools**: AWS CLI, Scaleway CLI, Terraform, Ansible
- **Kubernetes**: kubectl, helm, kind, kustomize, argocd, argo, kyverno, kubescape
- **CI/CD**: GitHub CLI, trivy, cosign, ct (chart-testing)
- **Development**: Node.js, Python, Go, Rust, Bun (via proto)
- **Utilities**: Docker, jq, yq, sops, age, mc, rclone, pandoc

> [!TIP]
> See complete tool list and build custom runner in `docker/utils/act-runner/Dockerfile`

### Setup

```sh
# Copy act directory to your project
curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
  -u "https://github.com/this-is-tobi/tools" -b "main" -s "act" -o "./act" -d

cd act
```

### Usage

```sh
# Run all workflows
./scripts/run-ci-locally.sh

# Run specific workflow
./scripts/run-ci-locally.sh -w .github/workflows/test.yml

# Use specific event template
./scripts/run-ci-locally.sh -e ./events/pr_base_main.json

# Start with local registry (port 5555)
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
- **kind** - Install: `brew install kind` or see [kind.sigs.k8s.io](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- **kubectl** - Install: `brew install kubectl` or see [kubernetes.io](https://kubernetes.io/docs/tasks/tools/)
- **helm** (optional) - Install: `brew install helm`

### Overview

Run a local Kubernetes cluster for development and testing. The wrapper provides:
- Simplified cluster management
- Docker Compose integration for multi-image builds
- Pre-configured ingress controller (Traefik or Nginx)
- Volume mounting for live development
- Port forwarding to host machine

The cluster uses `extraMounts` to bind the host working directory to `/app` inside containers, enabling live code updates.

### Setup

```sh
# Copy kind directory to your project
curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
  -u "https://github.com/this-is-tobi/tools" -b "main" -s "kind" -o "./kind" -d

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
      - containerPort: 80
        hostPort: 80
      - containerPort: 443
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

**Ingress controller**: Edit `run.sh` to switch between Traefik and Nginx.

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
kubectl get pods -n ingress-nginx  # or -n traefik
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
