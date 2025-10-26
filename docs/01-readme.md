# Tools :wrench:

A comprehensive collection of utility tools, scripts, and templates for modern development workflows. This repository provides reusable components for DevOps, CI/CD, containerization, and development automation.

## Overview

This repository serves as a centralized toolkit for developers and DevOps engineers, providing:

- Pre-built Docker images for development, debugging, and backup operations
- GitHub Copilot instructions for enhanced AI-assisted development
- Git hooks for enforcing code quality and commit conventions
- Shell scripts for automation, backup, and monitoring tasks
- Local development wrappers for GitHub Actions (act) and Kubernetes (kind)
- Node.js utilities for cryptography and parallel processing
- Kubernetes and ArgoCD templates for cloud-native deployments

## Repository Structure

```
tools/
├── act/              # Local GitHub Actions testing
├── ci/               # CI/CD configurations
├── copilot/          # GitHub Copilot instructions
├── devops/           # Kubernetes and ArgoCD templates
├── docker/           # Docker images and templates
├── docs/             # Documentation
├── git-hooks/        # Git hooks for quality checks
├── kind/             # Local Kubernetes development
├── node/             # Node.js utilities
└── shell/            # Automation scripts
```

## Quick Examples

**Use a shell script:**
```sh
curl -s https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/manage-etc-hosts.sh | bash -s -- --help
```

**Pull a Docker image:**
```sh
docker pull ghcr.io/this-is-tobi/tools/debug:latest
```

**Install a git hook:**
```sh
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/commit-msg/conventional-commit" \
  -o ".git/hooks/commit-msg"
chmod +x ".git/hooks/commit-msg"
```

**Setup Copilot instructions:**
```sh
mkdir -p .github/instructions
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/javascript.instructions.md" \
  -o ".github/instructions/javascript.instructions.md"
```

## External Resources

- **Repository**: <https://github.com/this-is-tobi/tools>
- **Container Registry**: <https://github.com/this-is-tobi/tools/pkgs/container/tools>
