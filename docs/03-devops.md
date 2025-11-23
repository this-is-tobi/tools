# DevOps

This section contains templates and configurations for modern DevOps practices, focusing on Kubernetes orchestration and CI/CD automation.

## Prerequisites

- **Kubernetes cluster** (for ArgoCD and runners)
- **kubectl** CLI tool configured
- **Helm** 3.x or higher (for runner installation)
- **ArgoCD** installed (for preview environments)
- **GitHub** account with appropriate permissions (for runners and ArgoCD integration)

## ArgoCD App Previews

Templates to configure preview environments with ArgoCD using the Pull Request Generator. The Pull Request generator uses the API of an SCM provider (GitHub, GitLab, Gitea, Bitbucket, etc.) to automatically discover open pull requests within a repository, enabling automatic test environment creation when PRs are opened.

**Available Templates:**
- [github-appset.yaml](../devops/argo-cd-app-preview/github-appset.yaml) - ApplicationSet for GitHub repositories

> For further information, see [ArgoCD documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Pull-Request).

## GitHub Self-Hosted Runners

Templates to deploy GitHub Actions Runners across a Kubernetes cluster.

### Installation Options

**Legacy Install (actions-runner-controller):**

1. Install [actions-runner-controller](https://github.com/actions/actions-runner-controller) Helm chart:
   ```sh
   # Get chart information
   helm show chart actions-runner-controller --repo https://actions-runner-controller.github.io/actions-runner-controller
   helm show values actions-runner-controller --repo https://actions-runner-controller.github.io/actions-runner-controller
   ```

2. Deploy the [runner-deployment.yaml](../devops/github-selfhosted-runner/runner-deployment.yaml)

**GitHub Official Install (Recommended):**

1. Install [actions-runner-controller](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/quickstart-for-actions-runner-controller) Helm chart:
   ```sh
   # Get chart information
   helm show chart oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
   helm show values oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
   ```

> For further information, see :
> - [Legacy ARC documentation](https://github.com/actions/actions-runner-controller).
> - [Github ARC documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/about-actions-runner-controller).

## Use Cases

### ArgoCD Preview Environments

Automatically create and destroy preview environments for pull requests:
- Testing features in isolated environments
- Review apps for frontend applications
- Integration testing before merging
- Automatic cleanup when PR closes

### Self-Hosted GitHub Runners

Run GitHub Actions on your own infrastructure:
- Access to specific hardware (GPU, high memory)
- Private network resource access
- Cost optimization for high CI/CD usage
- Custom software pre-installed

## Troubleshooting

### ArgoCD Preview Environments

**ApplicationSet not creating apps:**
- Verify GitHub token has `repo` scope
- Check ApplicationSet controller logs
- Ensure PR matches label filters
- Verify webhook configuration

**Apps not cleaning up:**
- Check preserveResourcesOnDeletion setting
- Verify ArgoCD has deletion permissions
- Check for blocking finalizers

### GitHub Self-Hosted Runners

**Runners not connecting:**
- Verify GitHub token/PAT validity and permissions
- Check runner pod logs
- Ensure network connectivity to github.com
- Verify registration token hasn't expired

**Jobs not using runners:**
- Check workflow `runs-on` labels match runner labels
- Verify runners are in "Idle" state
- Check runner group assignment
- Ensure repository has access to runner pool
