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
| [backup-kube-qdrant.sh](../shell/backup-kube-qdrant.sh)           | *backup / restore qdrant collection snapshots from / to a kubernetes pod.*      |
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

The backup scripts never put a password or token on a command line (where `ps` and the Kubernetes API audit log would show it): it reaches the pod on stdin, or the local client through its usual environment variable. Pass it through that variable rather than the `-p` / `-a` flag, which stays visible in the local process list. The `*_forward` modes forward a random free local port, so a database running on your machine is never touched, and every failure (dump, copy, port forward) makes the script exit non-zero instead of reporting success.

| Script                   | Secret variable  | Flag |
| ------------------------ | ---------------- | ---- |
| `backup-kube-pg.sh`      | `PGPASSWORD`     | `-p` |
| `backup-kube-mariadb.sh` | `MYSQL_PWD`      | `-p` |
| `backup-kube-vault.sh`   | `VAULT_TOKEN`    | `-p` |
| `backup-kube-qdrant.sh`  | `QDRANT_API_KEY` | `-a` |

**PostgreSQL:**
```sh
read -rs PGPASSWORD && export PGPASSWORD   # prompts without echo, stays out of the shell history
./backup-kube-pg.sh -m dump -n my-namespace -t my-postgres-pod -d mydatabase -u myuser -o ./backups
./backup-kube-pg.sh -m restore_forward -n my-namespace -t svc/my-postgres -d mydatabase -u myuser -f ./backups/20240101T1200-mydatabase.dump -z
```

**MariaDB:**
```sh
read -rs MYSQL_PWD && export MYSQL_PWD
./backup-kube-mariadb.sh -m dump_forward -n my-namespace -t my-mariadb-pod -d mydatabase -o ./backups
```

**Vault:**
```sh
read -rs VAULT_TOKEN && export VAULT_TOKEN
./backup-kube-vault.sh -m dump -n vault -t vault-0 -o ./backups
./backup-kube-vault.sh -m restore_forward -n vault -t vault-0 -f ./backups/20240101T1200-vault.snap
```

**Qdrant** (snapshots go through the HTTP API over a port forward, the former `dump` / `restore` modes are gone):
```sh
read -rs QDRANT_API_KEY && export QDRANT_API_KEY
./backup-kube-qdrant.sh -m dump_forward -n my-namespace -t qdrant-0 -o ./backups
./backup-kube-qdrant.sh -m restore_forward -n my-namespace -t qdrant-0 -f ./backups/20240101T1200-qdrant
```

### Monitoring

```sh
# PostgreSQL (CloudNativePG) cluster report
./monitor-kube-cnpg.sh -n database-namespace -c my-cluster

# Vault health check
./monitor-kube-vault.sh -n vault -v vault

# Redis cluster status
./monitor-kube-redis.sh -n redis-namespace -r my-redis

# Qdrant cluster status
./monitor-kube-qdrant.sh -n qdrant-namespace -q my-qdrant
```

### Resource Management

```sh
# Export Kubernetes resources (files are created readable by you only: they can hold secrets)
./export-kube-resources.sh -k all -n my-namespace -o ./exported

# Export ArgoCD applications
./export-argocd-resources.sh -k all -n argocd -o ./argocd-backup

# Generate a service account token (24h by default, read-only role without access to secrets)
./kube-generate-token.sh -n default -s my-service-account

# Write a kubeconfig file (mode 600); add -S to also grant read access to secrets
./kube-generate-token.sh -n default -s my-service-account -d 8h -f kubeconfig -o ~/.kube/config.d/my-service-account
```

`kube-generate-token.sh` prints only the token or kubeconfig on stdout, progress goes to stderr.

### Helm Chart Scaffolding

```sh
# Generate a chart with a base service and two more; pin the template with HELM_CHARTS_REF=<branch|tag|sha>
./helm-template.sh -c my-chart -s api -a worker -a client -o ./my-chart
```

### GitHub Container Registry

```sh
# Delete image
GITHUB_TOKEN=<token> ./delete-ghcr-image.sh -o owner -r repo -i image-name -t tag

# Purge old tags (dry run)
./purge-ghcr-tags.sh -o owner -r repo -i image-name -d 30 --dry-run
```

### Keycloak Management

```sh
# Get access token
./keycloak-get-token.sh -k https://keycloak.example.com -r my-realm -i client-id -s client-secret -u admin -p password

# List users
./keycloak-list-users.sh -k https://keycloak.example.com -r my-realm -u admin -p password

# Extract users to CSV
./keycloak-extract-users.sh -k https://keycloak.example.com -r my-realm -u admin -p password -b 100 -o users.csv

# Add users
./keycloak-add-users.sh -k https://keycloak.example.com -r my-realm -u admin -p password -d '[{"username":"user1","enabled":true}]'

# Check terms acceptance
./keycloak-check-tac.sh -k https://keycloak.example.com -r my-realm -u admin -p password
```

### Development Tools

```sh
# Clone subdirectory
./clone-subdir.sh -u https://github.com/owner/repo -b main -s path/to/dir -o ./output

# Generate GitHub Actions matrix
./compose-to-matrix.sh -f docker-compose.yml -o matrix.json

# Manage /etc/hosts
sudo ./manage-etc-hosts.sh add example.local 192.168.1.100
sudo ./manage-etc-hosts.sh remove example.local
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
# Set token as environment variable
export GITHUB_TOKEN=ghp_your_token_here

# Required scopes: repo, write:packages, admin:org (depending on script)
```

## Best Practices

- Always test with `--help` first
- Log output for audit trails: `./script.sh 2>&1 | tee log.txt`
- Use absolute paths in cron jobs
- Never hardcode credentials
- Store tokens securely
