# Shell Scripts

Bash/shell scripts for automation, backup operations, and system administration tasks.

## Prerequisites

- Bash 4.0+ or Zsh
- `curl` for downloading scripts
- `kubectl` (for Kubernetes scripts)
- `jq` (optional, for JSON processing)

## Quick Start

```sh
# Run directly (one-time use)
curl -s https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/<script_name> | bash -s -- --help

# Download and run (repeated use)
curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/<script_name> -o script.sh
chmod +x script.sh
./script.sh --help
```

## Available Scripts

| Script                                                            | Description                                                                     |
| ----------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| [backup-kube-mariadb.sh](../shell/backup-kube-mariadb.sh)         | *backup / restore mariadb database from / to a kubernetes pod.*                 |
| [backup-kube-pg.sh](../shell/backup-kube-pg.sh)                   | *backup / restore postgres database from / to a kubernetes pod.*                |
| [backup-kube-qdrant.sh](../shell/backup-kube-qdrant.sh)           | *backup / restore qdrant raft cluster from / to a kubernetes pod.*              |
| [backup-kube-vault.sh](../shell/backup-kube-vault.sh)             | *backup / restore vault raft cluster from / to a kubernetes pod.*               |
| [clone-subdir.sh](../shell/clone-subdir.sh)                       | *clone a subdirectory from a git repository.*                                   |
| [compose-to-matrix.sh](../shell/compose-to-matrix.sh)             | *parse docker-compose file to create github matrix.*                            |
| [delete-ghcr-image.sh](../shell/delete-ghcr-image.sh)             | *delete image and subsequent manifests from ghcr.*                              |
| [eol-infos.sh](../shell/eol-infos.sh)                             | *get package end of life infos.*                                                |
| [export-argocd-resources.sh](../shell/export-argocd-resources.sh) | *export ready-to-apply argocd resources.*                                       |
| [export-kube-resources.sh](../shell/export-kube-resources.sh)     | *export ready-to-apply kubernetes resources.*                                   |
| [github-create-app.sh](../shell/github-create-app.sh)             | *create a github application.*                                                  |
| [github-create-ruleset.sh](../shell/github-create-ruleset.sh)     | *create a github rulesets for a given repository.*                              |
| [github-configure-repo.sh](../shell/github-configure-repo.sh)     | *configure github repository security best practices.*                          |
| [helm-template.sh](../shell/helm-template.sh)                     | *generate helm template.*                                                       |
| [init-env-files.sh](../shell/init-env-files.sh)                   | *init '.env' and '.yaml' example files by copying them without 'example'.*      |
| [keycloak-add-clients.sh](../shell/keycloak-add-clients.sh)       | *add keycloak clients for a given keycloak realm.*                              |
| [keycloak-add-users.sh](../shell/keycloak-add-users.sh)           | *add keycloak users for a given keycloak realm.*                                |
| [keycloak-check-tac.sh](../shell/keycloak-check-tac.sh)           | *check how many users have accepted terms and conditions in a keycloak realm.*  |
| [keycloak-extract-users.sh](../shell/keycloak-extract-users.sh)   | *extract all users from a keycloak realm to a CSV file.*                        |
| [keycloak-get-token.sh](../shell/keycloak-get-token.sh)           | *display keycloak token for the given infos.*                                   |
| [keycloak-list-users.sh](../shell/keycloak-list-users.sh)         | *list keycloak users for a given keycloak realm.*                               |
| [keycloak-required-tac.sh](../shell/keycloak-required-tac.sh)     | *add terms and conditions required action to all realm users.*                  |
| [kube-generate-token.sh](../shell/kube-generate-token.sh)         | *generate a kubernetes token / kubeconfig with a given service account / RBAC.* |
| [manage-etc-hosts.sh](../shell/manage-etc-hosts.sh)               | *add or update host ip adress in /etc/hosts.*                                   |
| [monitor-kube-cnpg.sh](../shell/monitor-kube-cnpg.sh)             | *generate and print cnpg monitoring report.*                                    |
| [monitor-kube-qdrant.sh](../shell/monitor-kube-qdrant.sh)         | *generate and print qdrant monitoring report.*                                  |
| [monitor-kube-redis.sh](../shell/monitor-kube-redis.sh)           | *generate and print redis monitoring report.*                                   |
| [monitor-kube-vault.sh](../shell/monitor-kube-vault.sh)           | *generate and print vault monitoring report.*                                   |
| [purge-ghcr-tags.sh](../shell/purge-ghcr-tags.sh)                 | *purge ghcr tags older than a given date.*                                      |
| [setup-ai-agent.sh](../shell/setup-ai-agent.sh)                   | *bootstrap Claude Code / Copilot instructions, skills, agents, and safely run `rtk init -g --copilot`.* |
| [trivy-report.sh](../shell/trivy-report.sh)                       | *parse trivy json reports to create a markdown summary.*                        |
| [update-zsh-completions.sh](../shell/update-zsh-completions.sh)   | *update zsh-completions sources.*                                               |

> [!TIP]
> Using a script directly from a curl command:
> ```sh
> curl -s https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/<script_name> | bash -s -- -h
> ```

## Usage Examples

### Backup Operations

**PostgreSQL:**
```sh
./backup-kube-pg.sh backup -n namespace -p pod-name -d database -o backup.sql
./backup-kube-pg.sh restore -n namespace -p pod-name -d database -i backup.sql
```

**Vault:**
```sh
./backup-kube-vault.sh backup -n vault -p vault-0
./backup-kube-vault.sh restore -n vault -p vault-0 -i vault-backup.snap
```

### Monitoring

```sh
# PostgreSQL cluster report
./monitor-kube-cnpg.sh -n database-namespace -o report.md

# Vault health check
./monitor-kube-vault.sh -n vault

# Redis cluster status
./monitor-kube-redis.sh -n redis-namespace
```

### Resource Management

```sh
# Export Kubernetes resources
./export-kube-resources.sh -n my-namespace -o ./exported

# Export ArgoCD applications
./export-argocd-resources.sh -n argocd -o ./argocd-backup

# Generate service account token
./kube-generate-token.sh -n default -s my-service-account --kubeconfig
```

### GitHub Repository Settings

The GitHub scripts read the token from `GH_TOKEN`, then `GITHUB_TOKEN`, then `gh auth token`. The `-t` flag still works but exposes the token in the process list and the shell history.

```sh
# Merge strategy, Dependabot alerts, secret scanning, Actions policy (all actions allowed,
# pinned to a full commit SHA), read-only workflow token, tag protection for every tag
./github-configure-repo.sh -o owner -r repo -T '*'

# Only allow GitHub-owned actions and some patterns instead
./github-configure-repo.sh -o owner -r repo -a selected -L 'docker/*,owner/github-workflows/*'

# Classic branch protection on 'main'
./github-create-ruleset.sh -o owner -r repo -b main

# Repository ruleset on the default branch: required checks, pull requests without
# mandatory approval, repository admins may bypass
./github-create-ruleset.sh -o owner -r repo -m ruleset -c 'ci / lint,ci / test' -A 0 -a false

# Register a GitHub App (manifest flow: the browser opens, paste back the address GitHub redirects to)
./github-create-app.sh -n my-app -o owner -p '{"contents":"read"}' -w https://example.com/webhook -e push
```

`github-configure-repo.sh` leaves Dependabot security pull requests off by default (`-x true` turns them on when Renovate does not handle vulnerabilities). With `-H true` (the default), every action and reusable workflow must be referenced by a full commit SHA; it is not documented whether GitHub also enforces this for actions called from inside a composite action, so turn it off with `-H false` if a run fails on such an action. Both scripts update existing rulesets in place, so they can be run again.

### GitHub Container Registry

```sh
# Delete the version carrying exactly this tag and the untagged manifests it references
# (-n: dry run; -f: also when the version carries other tags, such as 'latest')
./delete-ghcr-image.sh -o owner -i image-name -t tag -n

# Purge versions older than a date (dry run first). Release tags ('latest', '1.2.3',
# 'api-v1.2.3', ...), what they reference and their signatures are kept unless -a is given
./purge-ghcr-tags.sh -u owner -i image-name -d 2024-01-01 -n
```

Both scripts need `docker buildx` to list the manifests an image references (`docker login ghcr.io` for private images) and follow the API pagination.

### Keycloak Management

The admin password is read from `KC_PASSWORD` (and the client secret of `keycloak-get-token.sh` from `KC_CLIENT_SECRET`); `-p` and `-s` still work but expose the value in the process list and the shell history. Passwords and tokens are handed to `curl` through stdin or a file descriptor, never as arguments.

```sh
read -rsp 'Password: ' KC_PASSWORD && export KC_PASSWORD

# Get access token
read -rsp 'Client secret: ' KC_CLIENT_SECRET && export KC_CLIENT_SECRET
./keycloak-get-token.sh -k https://keycloak.example.com -r my-realm -i client-id -u admin

# List users
./keycloak-list-users.sh -k https://keycloak.example.com -r my-realm -u admin

# Extract users to CSV (file created with mode 600, formula-like cells neutralized)
./keycloak-extract-users.sh -k https://keycloak.example.com -r my-realm -u admin -b 100 -o users.csv

# Add users or clients: inline JSON, '@file' or '-' (stdin) when they carry credentials
./keycloak-add-users.sh -k https://keycloak.example.com -r my-realm -u admin -d @users.json
./keycloak-add-clients.sh -k https://keycloak.example.com -r my-realm -u admin -c @clients.json

# Check terms acceptance
./keycloak-check-tac.sh -k https://keycloak.example.com -r my-realm -u admin
```

### Development Tools

```sh
# Clone a subdirectory (or a single file): './output/dir' is created, nothing else is written
./clone-subdir.sh -u https://github.com/owner/repo -b main -s path/to/dir -o ./output

# Generate GitHub Actions matrix
./compose-to-matrix.sh -f docker-compose.yml -n owner/repo -t 1.0.0 -a

# Map a host name in /etc/hosts (uses sudo only when needed; -f targets another file)
./manage-etc-hosts.sh -i 192.168.1.100 -n example.local
```

## Troubleshooting

### Permission Errors

```sh
# Make script executable
chmod +x script.sh

# Some scripts need sudo
sudo ./script.sh
```

### Kubernetes Connection

```sh
# Verify kubectl config
kubectl config current-context
kubectl cluster-info

# Check permissions
kubectl auth can-i get pods --all-namespaces
```

### GitHub Token Issues

```sh
# Reuse the gh CLI session (nothing to export)
gh auth login

# Or set the token in the environment without leaving it in the shell history
read -rs GH_TOKEN && export GH_TOKEN

# Required access: repository admin (configure-repo, create-ruleset),
# read:packages + delete:packages (ghcr scripts)
```

## Best Practices

- Always test with `--help` first
- Log output for audit trails: `./script.sh 2>&1 | tee log.txt`
- Use absolute paths in cron jobs
- Never hardcode credentials
- Store tokens securely
