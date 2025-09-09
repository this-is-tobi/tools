# Shell Scripts

Bash/shell scripts for automation, backup operations, and system administration tasks.

| Name                                                              | Description                                                                     |
| ----------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| [backup-kube-pg.sh](../shell/backup-kube-pg.sh)                   | *backup / restore postgres database from / to a kubernetes pod.*                |
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
> Using a script directly from a curl command :
> ```sh
> curl -s https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/<script_name> | bash -s -- -h
> ```
> Replace `<script_name>` by the name of the script you want to run (eg. `manage-etc-hosts.sh`).
