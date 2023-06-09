# Test CI/CD pipeline on the host locally

## Prerequisite

Download & install [act](https://github.com/nektos/act) on your local machine (this step is done in the local CI script).

```sh
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

## Test CI/CD

Put this directory in your git project, then :

```sh
# Go to the root level of the git project
cd `git rev-parse --show-toplevel`

# Start act wrapper
sh "$(find . -d -name 'act')"/scripts/run-ci-locally.sh
```

## Results analysis

Once the CI has finished running locally, artifacts are available in the folder `./artifacts/<date>/`.

## Local registry

It is possible to start a local docker registry running on port `5555` by adding `-r` flag on script `run-ci-locally.sh`.
For more details, see `./docker/registry/docker-compose.registry.yml`.

## Runner

Runner docker image can be customized in `./docker/Dockerfile`, by default it provides :
- docker
- nodejs
- tools for cypress
