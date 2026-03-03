---
applyTo: ".github/workflows/**/*.{yml,yaml}"
---

# GitHub Actions Instructions

You are an expert in GitHub Actions and CI/CD pipeline development.

## Workflow Best Practices

- Use descriptive workflow names and job names
- Organize workflows logically (CI, CD, security, etc.)
- Use proper trigger events (push, pull_request, schedule, workflow_dispatch)
- Implement proper branch protection rules
- Use semantic versioning for releases
- Implement proper secret management
- Use workflow templates for consistency across repositories

## Job and Step Organization

- Break down complex workflows into smaller, focused jobs
- Use meaningful step names with clear descriptions
- Implement proper job dependencies with needs
- Use conditional execution with if statements
- Group related steps logically
- Use proper error handling and failure strategies
- Implement proper timeouts for jobs and steps

## Security Practices

- Declare `permissions:` explicitly at the **job level**; never rely on repository defaults
- Use the minimum set of permissions required — default to `contents: read`
- Use OIDC for cloud provider authentication; never store long-lived cloud credentials in secrets
- **Pin actions to a full commit SHA**, not a mutable tag (e.g., `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`)
- Use only trusted and verified actions; prefer GitHub-owned and well-maintained community actions
- **Never use `pull_request_target` with an untrusted code checkout** — this gives write permissions to external PRs and is a critical security risk
- Use environment protection rules and required reviewers for sensitive deployments (`production`, `release`)
- Avoid printing secrets in logs; use `::add-mask::` for dynamic values
- Use `CODEOWNERS` combined with environment approvals for change control
- Enable secret scanning and push protection on the repository

```yaml
# Minimal permissions example
permissions:
  contents: read

jobs:
  build:
    permissions:
      contents: read
      packages: write   # only on the job that needs it
```

## Reusable Workflows

- Extract repeated job patterns into reusable workflows (`workflow_call`)
- Pass inputs and secrets explicitly; never use `secrets: inherit` in security-sensitive workflows
- Version reusable workflows with tags or SHAs when consumed across repositories
- Document inputs, outputs, and secrets in the workflow file header

## Performance Optimization

- Use caching for dependencies and build artifacts
- Implement matrix strategies for parallel execution
- Use self-hosted runners for better performance when needed
- Optimize Docker builds with multi-stage builds and layer caching
- Use artifacts efficiently for job communication
- Implement proper cleanup of resources
- Use `concurrency:` groups to cancel stale runs on PR updates

## Action Development

- Use TypeScript for JavaScript actions
- Implement proper input validation and error handling
- Use semantic versioning and proper release strategies
- Include comprehensive documentation and examples
- Use proper action metadata in action.yml
- Implement proper testing for custom actions
- Follow GitHub's action development best practices

## Common Patterns

CI Workflows:
- Lint, test, and build on every push and PR
- Use matrix strategies for multiple environments
- Implement proper test reporting and coverage
- Use proper artifact management
- Implement security scanning and dependency checks

CD Workflows:
- Use environment-specific deployments
- Implement proper approval processes
- Use blue-green or rolling deployment strategies
- Implement proper rollback mechanisms
- Use proper monitoring and health checks

## Marketplace Actions

Commonly used and trusted actions:
- actions/checkout@v4 for repository checkout
- actions/setup-node@v4 for Node.js setup
- actions/setup-go@v5 for Go setup
- actions/setup-python@v5 for Python setup
- actions/cache@v4 for dependency caching
- actions/upload-artifact@v4 for artifact upload
- actions/download-artifact@v4 for artifact download
- docker/build-push-action@v5 for Docker builds
- azure/k8s-deploy@v1 for Kubernetes deployments

## Workflow Syntax

- Use proper YAML syntax and indentation
- Use environment variables appropriately
- Implement proper input and output handling
- Use proper expressions and functions
- Use workflow commands for logging and debugging
- Implement proper status checks and reporting

## Monitoring and Debugging

- Use proper logging with workflow commands
- Implement proper error reporting
- Use debug mode when troubleshooting
- Monitor workflow execution times and costs
- Implement proper alerting for failed workflows
- Use workflow insights for optimization

## Integration Patterns

- Integrate with external services (Slack, Teams, etc.)
- Use webhooks for custom integrations
- Implement proper API calls with authentication
- Use proper status updates for external systems
- Implement proper notification strategies
