# Development Tools

Local development environment tools and wrappers for testing and development workflows.

| Wrapper         | Purpose                                         | Entry point            |
| --------------- | ----------------------------------------------- | ---------------------- |
| [Act](#act)     | Run the GitHub Actions workflows of a project   | `./act/run.sh`         |
| [Kind](#kind)   | Run a local Kubernetes cluster and deploy to it | `./kind/run.sh <cmd>`  |

Both wrappers work the same way:

- **Copy one folder into your project and run it.** Each wrapper is self-contained and the entry point is always `run.sh`.
- **Run it from anywhere in the project.** The wrapper finds the project root (the git top level) and works from there.
- **Nothing to edit in `run.sh`.** Project settings live in files you own (`env/.env`, `hooks/`), so copying a newer version of the wrapper does not overwrite your setup.
- **Missing tool? It offers to install it.** The CLI is downloaded as a pinned release and checked against its checksum before it is installed. `-y` answers yes, and a script run without a terminal fails with the install command instead of waiting for an answer.
- **`-h` prints the help**, and `NO_COLOR` turns the colors off.

## Act

Local GitHub Actions testing wrapper for running workflows on your machine.

### Prerequisites

- **Docker** or **Podman**, running
- **jq**
- **act** CLI - Install: `brew install act` or see [nektos/act](https://github.com/nektos/act). When it is missing, `run.sh` offers to install a pinned release after checking it against the release checksums.
- **Git** repository with GitHub Actions workflows

### Overview

Test GitHub Actions workflows locally before pushing to remote. The wrapper provides:
- A pre-configured runner with common development tools
- Event templates for different GitHub events (PR, push, tags)
- Local Docker registry support
- Artifact collection

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
# Copy the act directory to your project (creates ./act)
curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
  -u "https://github.com/this-is-tobi/tools" -b "main" -s "wrapper/act" -o "."
```

### Usage

```sh
# Run every workflow of .github/workflows, as a pull request to main
./act/run.sh

# Run a single job
./act/run.sh -j lint

# Run a specific workflow, with a specific event
./act/run.sh -w .github/workflows/test.yml -e act/events/push_base_main.json

# List the workflows, jobs and their graph for the event without running anything
./act/run.sh -l

# Start a local registry (127.0.0.1:5555, stopped when the run ends)
./act/run.sh -r

# Hand flags to act (here for Apple Silicon)
./act/run.sh -- --container-architecture linux/amd64

# Review artifacts, the path is printed at the end of the run
ls ./act/artifacts/
```

The script can be called from anywhere in the project: act always starts from the project root, so the jobs see the whole repository.

Available event templates in `events/`:
- `pr_base_main.json` - Pull request to main (default)
- `pr_draft.json` - Draft pull request
- `pr_not_draft.json` - Non-draft pull request
- `push_base_main.json` - Push to main branch
- `push_tag.json` - Tag push

### Configuration

**Runner image**: the `ubuntu-latest`, `ubuntu-26.04`, `ubuntu-24.04` and `ubuntu-22.04` jobs run in the [`act-runner`](https://github.com/this-is-tobi/tools/tree/main/docker/utils/act-runner) image. It is only pulled when it is missing locally: `docker pull ghcr.io/this-is-tobi/tools/act-runner:latest` refreshes it. To use another image, build `act/runners/Dockerfile` (or any image) and set `ACT_RUNNER_IMAGE`.

**Wrapper settings** (environment or `env/.env`, copied from `env/.env-example`):

| Variable            | Purpose                                                            |
| ------------------- | ------------------------------------------------------------------ |
| `ACT_RUNNER_IMAGE`  | Image of the `ubuntu-*` jobs                                       |
| `REGISTRY_HOST`     | Registry address given to the jobs (default `localhost:5555`)      |
| `REGISTRY_PORT`     | Registry port published on `127.0.0.1` (default `5555`)            |
| `REGISTRY_USERNAME` | Registry user, no default                                          |
| `REGISTRY_SECRET`   | Registry password, no default                                      |

`REGISTRY_USERNAME` and `REGISTRY_SECRET` are only needed with `-r`, and the registry refuses to start without them. The registry is published on `127.0.0.1` only, and the credentials reach `htpasswd` through stdin and `act` by variable name, so they never show in the process list. Generated files (`env/.env`, `registry/auth`, `registry/certs`, `registry/data`, `artifacts`) are git-ignored by `act/.gitignore`.

**act files**, read from the project root:

```sh
# Secrets
echo "MY_TOKEN=secret_value" > .secrets

# Flags used on every run
cat > .actrc <<'EOF'
--container-architecture=linux/amd64
EOF
```

### Troubleshooting

**Docker is not running:** start Docker Desktop (or your container engine), the script checks it before anything else.

**Docker permission denied:**
```sh
sudo usermod -aG docker $USER
newgrp docker
```

**Workflow path does not exist:** the default is `.github/workflows` at the project root, use `-w` to point to another file or directory.

**Nothing runs:** the event must match the `on:` of the workflow. `./act/run.sh -l` lists what the event triggers, and `-e` picks another event.

**Apple Silicon warning or image errors:** run with `-- --container-architecture linux/amd64`, or put the flag in `.actrc`.

## Kind

Local Kubernetes development environment using Kubernetes in Docker.

### Prerequisites

- **Docker** or **Podman**, running, with `buildx`
- **helm** - Install: `brew install helm`
- **kind** - Install: `brew install kind` or see [kind.sigs.k8s.io](https://kind.sigs.k8s.io/docs/user/quick-start/#installation). When it is missing, `run.sh` offers to install a pinned release after checking its sha256.
- **kubectl** - Install: `brew install kubectl` or see [kubernetes.io](https://kubernetes.io/docs/tasks/tools/)

### Overview

Run a local Kubernetes cluster for development and testing. The wrapper provides:
- Simple cluster management (`dev`, `delete`)
- Docker Compose integration to build several images at once and load them into the cluster
- A Traefik ingress controller, exposed on the host ports 80 and 443
- The project mounted in the node at `/app`, for live development
- Hooks to deploy your application

### Setup

```sh
# Copy the kind directory to your project (creates ./kind)
curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
  -u "https://github.com/this-is-tobi/tools" -b "main" -s "wrapper/kind" -o "."
```

Then make it yours, in the two files meant for that:

1. `kind/docker-compose.yml`: declare the images to build. The script refuses to build while the template placeholders are still there.
2. `kind/hooks/deploy.sh`: install your application in the cluster, an example with helm is in the file.

### Usage

```sh
# Create the cluster, build and load the images, deploy
./kind/run.sh dev

# Step by step
./kind/run.sh create    # Create the cluster
./kind/run.sh build     # Build and load the images
./kind/run.sh deploy    # Run hooks/deploy.sh
./kind/run.sh delete    # Delete the cluster

# Commands can be combined
./kind/run.sh create build

# Deploy in prod mode, with an image tag
./kind/run.sh prod -t 1.0.0

# Map local domains to 127.0.0.1 in /etc/hosts (sudo, missing names only)
./kind/run.sh dev -d 'api.domain.local,doc.domain.local'

# Work with several clusters
./kind/run.sh dev -n shop

# View help
./kind/run.sh -h

# Access application
kubectl get services
kubectl port-forward svc/myapp 8080:80
curl http://localhost/  # Via ingress
```

The script can be called from anywhere in the project. Commands are always run in the same order: the cluster is created while the images build, then the images are loaded, the application is deployed, cleaned and the cluster deleted.

The previous syntax `./kind/run.sh -c create,build` is still accepted.

### Configuration

**Hooks** (`hooks/deploy.sh` and `hooks/clean.sh`) are your code: `run.sh` stays untouched when you update the wrapper. They run from the project root with:

| Variable            | Content                                                     |
| ------------------- | ----------------------------------------------------------- |
| `$1` (deploy only)  | Mode, `dev` or `prod` (see `env/helm-values.<mode>.yaml`)   |
| `IMAGE_TAG`         | Tag given with `-t`, empty by default                       |
| `KUBE_CONTEXT`      | kubectl / helm context of the cluster                       |
| `KIND_CLUSTER_NAME` | Name of the cluster                                         |
| `PROJECT_ROOT`      | Absolute path of the project                                |

```sh
#!/bin/bash
# hooks/deploy.sh
set -euo pipefail

helm upgrade --install my-app "$PROJECT_ROOT/helm" \
  --kube-context "$KUBE_CONTEXT" \
  --values "$PROJECT_ROOT/kind/env/helm-values.${1}.yaml" \
  ${IMAGE_TAG:+--set image.tag="$IMAGE_TAG"}
```

**Images** (`docker-compose.yml`): only the services with a `build` section are built and loaded.
```yaml
services:
  api:
    build:
      context: ..
      dockerfile: api/Dockerfile
    image: myapp/api:local
  frontend:
    build:
      context: ..
      dockerfile: frontend/Dockerfile
    image: myapp/frontend:local
```

**Cluster** (`configs/kind-config.yml`): a single control-plane node. The ingress controller listens on the node ports 30080 and 30443, mapped to the host ports 80 and 443, and the project root is mounted at `/app`.
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 80
  - containerPort: 30443
    hostPort: 443
  extraMounts:
  - hostPath: ./
    containerPath: /app
```

**Ingress controller**: [Traefik](https://doc.traefik.io/traefik/), installed from a pinned chart version with `configs/traefik-values.yml`. `create` on an existing cluster reuses it and installs Traefik when it is missing.

**Cluster name**: `kind` by default, `-n` or `KIND_CLUSTER_NAME` to change it. The kubectl context is `kind-<name>`. The ingress uses fixed host ports, so only one cluster can run at a time.

### Troubleshooting

**Cluster creation fails:**
```sh
# Check Docker is running
docker ps

# Delete and recreate
./kind/run.sh delete
./kind/run.sh create
```

**Port conflict:** another process or another kind cluster uses the port 80 or 443.
```sh
# Find process using port
lsof -i :80
lsof -i :443

# Change the host ports in configs/kind-config.yml
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
# Check the ingress controller status
kubectl get pods -n ingress-traefik
kubectl get ingress

# Test from within cluster
kubectl run test --rm -it --image=curlimages/curl -- curl http://myservice
```

### Best Practices

- Version `configs/kind-config.yml` and `hooks/` in git
- Tag images as `local` to distinguish them from registry images
- Use `imagePullPolicy: IfNotPresent` in manifests, the images are loaded in the nodes
- Set resource limits in manifests
