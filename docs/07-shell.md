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
| [helm-template.sh](../shell/helm-template.sh)                     | *generate helm template.*                                                       |
| [init-env-files.sh](../shell/init-env-files.sh)                   | *init '.env' and '.yaml' example files by copying them without 'example'.*      |
| [keycloak-add-clients.sh](../shell/keycloak-add-clients.sh)       | *add keycloak clients for a given keycloak realm.*                              |
| [keycloak-add-users.sh](../shell/keycloak-add-users.sh)           | *add keycloak users for a given keycloak realm.*                                |
| [keycloak-check-tac.sh](../shell/keycloak-check-tac.sh)           | *check how many users have accepted terms and conditions in a keycloak realm.*  |
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

### GitHub Container Registry

```sh
# Delete image
GITHUB_TOKEN=<token> ./delete-ghcr-image.sh -o owner -r repo -i image-name -t tag

# Purge old tags (dry run)
./purge-ghcr-tags.sh -o owner -r repo -i image-name -d 30 --dry-run
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
