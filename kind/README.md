# Run kubernetes locally with docker

## Prerequisite

Download & install on your local machine :
- [kind](https://github.com/kubernetes-sigs/kind)
- [kubectl](https://github.com/kubernetes/kubectl)
- [helm](https://github.com/helm/helm)

Declare your images into the `./docker-compose.yml` file, it is used for parralel build and load images into Kind nodes.

## Commands

Put this directory in your git project, then start using the script :

```sh
# Start kind cluster
./run.sh -c create

# Build and load docker-compose images into the cluster
./run.sh -c build

# Stop kind cluster
./run.sh -c delete

# Start kind cluster, build and load images and deploy app
./run.sh -c dev
```

> [!TIP]
> See script helper by running `./run.sh -h`

## Cluster

One single node is deployed but it can be customized in `./configs/kind-config.yml`. The cluster comes with [Traefik](https://doc.traefik.io/traefik/providers/kubernetes-ingress/) (default) or [Nginx](https://kind.sigs.k8s.io/docs/user/ingress/#ingress-nginx) (`-i nginx`) ingress controller installed, exposed on node ports `30080` and `30443` which are mapped to the host ports `80` and `443`.

> [!WARNING]
> The ingress-nginx project was [retired in March 2026](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/) and receives no more releases or security fixes. `run.sh` pins it to its last release (`controller-v1.15.1`); prefer Traefik.

The node is using `extraMounts` to provide a volume binding between host working directory and `/app` to give the ability to bind mount volumes into containers during development.
