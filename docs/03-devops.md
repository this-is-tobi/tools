# DevOps

This section contains templates and configurations for modern DevOps practices, focusing on Kubernetes orchestration and CI/CD automation.

## ArgoCD App Previews

Templates to configure preview environments with ArgoCD by using the Pull Request Generator. The Pull Request generator uses the API of an SCMaaS provider (GitHub, GitLab, Gitea, Bitbucket, ...) to automatically discover open pull requests within a repository, this fits well with the style of building a test environment when you create a pull request.

- [github-appset.yaml](../devops/argo-cd-app-preview/github-appset.yaml)

> For further information, see [ArgoCD documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Pull-Request).

## Github Self-Hosted Runners

Templates to deploy Github Actions Runners across a Kubernetes cluster.

Using **legacy** install:
  1. Install [actions-runner-controller](https://github.com/actions/actions-runner-controller) helm chart.
      ```sh
      # Get chart informations

      helm show chart actions-runner-controller --repo https://actions-runner-controller.github.io/actions-runner-controller
      helm show values actions-runner-controller --repo https://actions-runner-controller.github.io/actions-runner-controller
      ```
  1. Deploy the [runner-deployment.yaml](../devops/github-selfhosted-runner/runner-deployment.yaml).

Using **github** install:
  1. Install [actions-runner-controller](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/quickstart-for-actions-runner-controller) helm chart.
      ```sh
      # Get chart informations

      helm show chart oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
      helm show values oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
      ```

> For further information, see :
> - [Legacy ARC documentation](https://github.com/actions/actions-runner-controller).
> - [Github ARC documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/about-actions-runner-controller).
