# Run Kubernetes locally with Docker

Runs a local Kubernetes cluster with [kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker), builds your images into it and deploys your application.

## Prerequisites

- Docker (or any engine providing the `docker` CLI), running, with `buildx`
- [helm](https://helm.sh/): `brew install helm`
- [kind](https://kind.sigs.k8s.io/): `brew install kind`. When it is missing, the script offers to install a pinned release after checking its checksum (`-y` answers yes).
- [kubectl](https://kubernetes.io/docs/tasks/tools/), for your own use and for the hooks

## Install

From the root of your project:

```sh
curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
  -u "https://github.com/this-is-tobi/tools" -b "main" -s "wrapper/kind" -o "."
```

Then make it yours, in the two files meant for that:

1. `docker-compose.yml`: declare the images to build. The script refuses to build while the template placeholders are still there.
2. `hooks/deploy.sh`: install your application in the cluster (an example with helm is in the file). `hooks/clean.sh` removes it.

## Usage

```sh
./kind/run.sh dev       # create the cluster, build and load the images, deploy
./kind/run.sh delete    # delete the cluster
./kind/run.sh -h        # all commands and flags
```

The script can be called from anywhere in the project.

| Command  | Purpose                                                              |
| -------- | -------------------------------------------------------------------- |
| `dev`    | `create`, `build` and `deploy` in dev mode                           |
| `prod`   | `create`, `build` and `deploy` in prod mode                          |
| `create` | Create the cluster and its Traefik ingress controller                |
| `build`  | Build the images of the compose file and load them into the cluster  |
| `load`   | Load the images of the compose file into the cluster                 |
| `deploy` | Run `hooks/deploy.sh` in dev mode                                    |
| `clean`  | Run `hooks/clean.sh`                                                 |
| `delete` | Delete the cluster                                                   |

Commands can be combined (`./kind/run.sh create build`) and are run in a fixed order, the cluster being created while the images build.

| Flag | Purpose                                                                    |
| ---- | -------------------------------------------------------------------------- |
| `-d` | Domains to add to `/etc/hosts`, comma separated (sudo)                     |
| `-f` | Compose file declaring the images (default `docker-compose.yml`)           |
| `-n` | Cluster name (default `kind`, or `KIND_CLUSTER_NAME`), context `kind-<name>` |
| `-t` | Image tag, handed to the deploy hook as `IMAGE_TAG`                        |
| `-y` | Install kind without asking when it is missing                             |

## Hooks

`hooks/deploy.sh` and `hooks/clean.sh` are your code: `run.sh` stays untouched. They run from the project root with:

| Variable            | Content                                                  |
| ------------------- | -------------------------------------------------------- |
| `$1` (deploy only)  | Mode, `dev` or `prod` (see `env/helm-values.<mode>.yaml`) |
| `IMAGE_TAG`         | Tag given with `-t`, empty by default                    |
| `KUBE_CONTEXT`      | kubectl / helm context of the cluster                    |
| `KIND_CLUSTER_NAME` | Name of the cluster                                      |
| `PROJECT_ROOT`      | Absolute path of the project                             |

## Cluster

One control-plane node, customizable in `configs/kind-config.yml`.

- The project root is mounted in the node at `/app`, to bind mount sources into containers during development.
- [Traefik](https://doc.traefik.io/traefik/) is installed from a pinned chart (`configs/traefik-values.yml`) and exposed on the host ports `80` and `443` (node ports `30080` and `30443`). Ports are bound by one cluster at a time: delete the other one first.
- Running `create` again on an existing cluster reuses it, and installs Traefik if it is missing.
