# Test CI/CD pipeline on the host locally

## Prerequisite

Download & install [act](https://github.com/nektos/act) on your local machine (this step is done in the local CI script).

```sh
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

## Test CI/CD

Put this directory in your git project, then :

```sh
# Start act
sh run-ci-locally.sh
```

## Results analysis

Once the CI has finished running locally, artifacts are available in the folder `./artifacts/<date>/`.

## Local registry

It is possible to start a local docker registry running on port `5555` by adding `-r` flag on script `run-ci-locally.sh`.
For more details, see `./registry/docker-compose.registry.yml`.

## Runner

The default runner uses [dotfiles](https://github.com/this-is-tobi/dotfiles) to install and configure all the standard tools needed for development and CI/CD.

> [!TIP]
> See all tools installed in the default runner by checking `./runners/Dockerfile`.
