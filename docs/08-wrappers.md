# Development Tools

Local development environment tools and wrappers for testing and development workflows.

| Name                                               | Description                        |
| -------------------------------------------------- | ---------------------------------- |
| [act](https://github.com/this-is-tobi/tools/act)   | *local github action act wrapper.* |
| [kind](https://github.com/this-is-tobi/tools/kind) | *local kubernetes kind wrapper.*   |

## Act - GitHub Actions on Local

### Prerequisite

Download & install [act](https://github.com/nektos/act) on your local machine (this step is done in the local CI script).

```sh
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

### Test CI/CD

Put this directory in your git project, then :

```sh
# Start act
sh run-ci-locally.sh
```

### Results analysis

Once the CI has finished running locally, artifacts are available in the folder `./artifacts/<date>/`.

### Local registry

It is possible to start a local docker registry running on port `5555` by adding `-r` flag on script `run-ci-locally.sh`.
For more details, see `./registry/docker-compose.registry.yml`.

### Runner

The default runner uses [dotfiles](https://github.com/this-is-tobi/dotfiles) to install and configure all the standard tools needed for development and CI/CD.

> [!TIP]
> See all tools installed in the default runner by checking `./runners/Dockerfile`.

## Kind - Kubernetes in Docker

### Prerequisite

Download & install on your local machine :
- [kind](https://github.com/kubernetes-sigs/kind)
- [kubectl](https://github.com/kubernetes/kubectl)
- [helm](https://github.com/helm/helm)

Declare your images into the `./docker-compose.yml` file, it is used for parralel build and load images into Kind nodes.

### Commands

Put this directory in your git project, then start using the script :

```sh
# Start kind cluster
sh ./run.sh -c create

# Build and load docker-compose images into the cluster
sh ./run.sh -c build

# Stop kind cluster
sh ./run.sh -c delete

# Start kind cluster, build and load images and deploy app
sh ./run.sh -c dev
```

> [!TIP]
> See script helper by running `sh ./run.sh -h`

### Cluster

One single node is deployed but it can be customized in `./configs/kind-config.yml`. The cluster comes with [Traefik](https://doc.traefik.io/traefik/providers/kubernetes-ingress/) or [Nginx](https://kind.sigs.k8s.io/docs/user/ingress/#ingress-nginx) ingress controller installed with port mapping on both ports `80` and `443`.

The node is using `extraMounts` to provide a volume binding between host working directory and `/app` to give the ability to bind mount volumes into containers during development.
