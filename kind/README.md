# Run kubernetes locally with docker

## Prerequisite

Download & install on your local machine :
-  [kind](https://github.com/kubernetes-sigs/kind)
- [kubectl](https://github.com/kubernetes/kubectl)
- [helm](https://github.com/helm/helm)

## Start cluster

Put this directory in your git project, then :

```sh
# Go to the root level of the git project
cd `git rev-parse --show-toplevel`

# Start kind wrapper
sh "$(find . -d -name 'kind')"/run.sh -c create

# Push your docker-compose images into the cluster
sh "$(find . -d -name 'kind')"/run.sh -c build -f docker-compose.yml -t latest

# Stop kind wrapper
sh "$(find . -d -name 'kind')"/run.sh -c delete
```

## Cluster

One single node is deployed but it can be customized in `./configs/kind-config.yml`. The cluster comes with [Traefik](https://doc.traefik.io/traefik/providers/kubernetes-ingress/) ingress controller installed with port mapping on both ports `80` and `443`.

## Local registry

A local docker registry is deployed through Docker on the port `5001` and connected already with the cluster so you can pull your image from it.


