# Run GitHub Actions workflows locally

Runs the workflows of your project on your machine with [act](https://github.com/nektos/act), in the same runner image as the CI of this repository.

## Prerequisites

- Docker (or any engine providing the `docker` CLI), running
- `jq`
- [act](https://github.com/nektos/act): `brew install act`. When it is missing, the script offers to install a pinned release after checking its checksum (`-y` answers yes).

## Install

From the root of your project:

```sh
curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
  -u "https://github.com/this-is-tobi/tools" -b "main" -s "wrapper/act" -o "."
```

## Usage

```sh
./act/run.sh                 # every workflow of .github/workflows, as a pull request to main
./act/run.sh -j lint         # one job only
./act/run.sh -l              # list workflows, jobs and their graph, run nothing
./act/run.sh -h              # all flags
```

The script can be called from anywhere in the project: act always starts from the project root.

| Flag | Purpose                                                                            |
| ---- | ---------------------------------------------------------------------------------- |
| `-e` | Event that triggers the workflows (default `events/pr_base_main.json`)             |
| `-j` | Run a single job, given its id                                                     |
| `-l` | List workflows, jobs and their graph, then exit                                    |
| `-r` | Start a local docker registry for the run                                          |
| `-w` | Workflow file or directory (default `.github/workflows`)                           |
| `-y` | Install act without asking when it is missing                                      |

Anything after `--` goes to act as is, e.g. `./act/run.sh -- --container-architecture linux/amd64` on Apple Silicon.

Events are in `events/`: `pr_base_main`, `pr_draft`, `pr_not_draft`, `push_base_main` and `push_tag`.

## Configuration

Nothing needs to be edited in `run.sh`. act reads the usual files from the project root: `.actrc`, `.secrets`, `.env` and `.vars`.

Settings of the wrapper come from the environment or from `env/.env` (git-ignored, copy `env/.env-example`):

| Variable            | Purpose                                                                                    |
| ------------------- | ------------------------------------------------------------------------------------------ |
| `ACT_RUNNER_IMAGE`  | Image the `ubuntu-*` jobs run in (default `ghcr.io/this-is-tobi/tools/act-runner:latest`)  |
| `REGISTRY_USERNAME` | Local registry user (no default)                                                           |
| `REGISTRY_SECRET`   | Local registry password (no default)                                                       |

## Runner

The default runner is the [`act-runner`](https://github.com/this-is-tobi/tools/tree/main/docker/utils/act-runner) image, used for `ubuntu-latest`, `ubuntu-26.04`, `ubuntu-24.04` and `ubuntu-22.04`. It is only pulled when missing locally: run `docker pull ghcr.io/this-is-tobi/tools/act-runner:latest` to refresh it.

To use your own, build `runners/Dockerfile` (or any image) and set `ACT_RUNNER_IMAGE`.

## Results

Artifacts uploaded by the workflows are available in `./act/artifacts/<run id>/`, the path is printed at the end of the run.

## Local registry

`-r` starts a docker registry on `127.0.0.1:5555` for the run and stops it when the run ends. Its credentials come from `env/.env` or from the environment: `REGISTRY_USERNAME` and `REGISTRY_SECRET` have no default. See `registry/docker-compose.registry.yml` for the details.
