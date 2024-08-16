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
sh ./run.sh -c create

# Build and load docker-compose images into the cluster
sh ./run.sh -c build

# Stop kind cluster
sh ./run.sh -c delete

# Start kind cluster, build and load images and deploy app
sh ./run.sh -c dev
```

> [!TIP]
> See script helper by running `sh ./run.hs -h`

## Cluster

One single node is deployed but it can be customized in `./configs/kind-config.yml`. The cluster comes with [Traefik](https://doc.traefik.io/traefik/providers/kubernetes-ingress/) or [Nginx](https://kind.sigs.k8s.io/docs/user/ingress/#ingress-nginx) ingress controller installed with port mapping on both ports `80` and `443`.

The node is using `extraMounts` to provide a volume binding between host working directory and `/app` to give the ability to bind mount volumes into containers during development.
