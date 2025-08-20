# Copilot Instructions for Tools Repository

This repository contains utility tools & scripts for various development tasks.

## Repository Overview

- **Purpose**: Collection of utility tools, scripts, and templates for development workflows
- **Size**: Medium-sized repository with multiple technology stacks
- **Technologies**: Bash/Shell, Docker, Kubernetes/Helm, GitHub Actions, Node.js, Python
- **Structure**: Organized by technology/purpose in separate directories

## Build and Development

### Prerequisites

- Docker and Docker Compose
- Kubernetes cluster (for K8s tools testing)
- Node.js 22+ (for Node.js tools)
- Go 1.25+ (for any Go tools)
- Bash 4.0+ (for shell scripts)

### Common Commands

- **Linting**: Use respective linters for each technology (shellcheck for bash, hadolint for Docker, etc.)
- **Testing**: Most tools are meant to be copied and used in other projects
- **Building**: Docker images are built via GitHub Actions workflows

## Validation and Testing

### Shell Scripts

- All shell scripts should be validated with `shellcheck`
- Test scripts in isolated environments before use
- Use `bash -n script.sh` for syntax validation

### Docker Images

- Validate Dockerfiles with `hadolint`
- Test image builds locally before pushing
- Use multi-stage builds for optimization

### GitHub Actions

- Validate workflow syntax with `action-validator`
- Test workflows in feature branches
- Use `act` for local workflow testing (see `/act/` directory)

## Development Guidelines

- Follow conventional commit format for all commits
- Use meaningful names for files and directories
- Include proper documentation for new tools
- Test all changes in isolated environments
- Use proper error handling in all scripts
- Follow security best practices for all tools

## Dependencies and Versions

- Most tools are designed to be dependency-free or use minimal dependencies
- See individual Dockerfiles for specific base image versions
- Shell scripts target Bash 4.0+ for broad compatibility
- Node.js tools target Node.js 22+ LTS

## Common Issues and Solutions

### Shell Scripts

- Always use `set -euo pipefail` for error handling
- Quote variables to prevent word splitting
- Use `mktemp` for temporary files

### Docker Images

- Use specific base image tags, not `latest`
- Implement proper health checks
- Run containers as non-root users

### GitHub Actions

- Pin action versions to specific commits or tags
- Use caching for dependencies and build artifacts
- Implement proper secret management
