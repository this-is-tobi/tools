# Test CI/CD pipeline on the host locally

## Prerequisite

Download & install [act](https://github.com/nektos/act) on your local machine, e.g. `brew install act`. When act is missing, the local CI script offers to install a pinned release after checking it against the release checksums.

## Test CI/CD

Put this directory in your git project, then :

```sh
# Start act
./scripts/run-ci-locally.sh
```

## Results analysis

Once the CI has finished running locally, artifacts are available in the folder `./artifacts/<date>/`.

## Local registry

It is possible to start a local docker registry running on `127.0.0.1:5555` by adding `-r` flag on script `run-ci-locally.sh`. It is stopped when the run ends.
Its credentials come from `./env/.env` (copy `./env/.env-example`, the file is git-ignored) or from the environment: `REGISTRY_USERNAME` and `REGISTRY_SECRET` have no default.
For more details, see `./registry/docker-compose.registry.yml`.

## Runner

The default runner uses [dotfiles](https://github.com/this-is-tobi/dotfiles) to install and configure all the standard tools needed for development and CI/CD.

> [!TIP]
> See all tools installed in the default runner by checking `./runners/Dockerfile`.
