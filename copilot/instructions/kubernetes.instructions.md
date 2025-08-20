---
applyTo: "**/*.{yaml,yml}"
---

# Kubernetes & Helm Instructions

You are an expert in Kubernetes and Helm chart development.

## Kubernetes Guidelines

- Always use the latest stable API versions for Kubernetes resources
- Prefer Deployments over ReplicaSets or bare Pods
- Include proper resource requests and limits
- Add appropriate labels and selectors following Kubernetes best practices
- Use meaningful names that follow DNS-1035 conventions
- Include proper health checks (readiness and liveness probes)
- Use ConfigMaps and Secrets for configuration management
- Follow security best practices (non-root containers, read-only filesystems when possible)
- Implement proper RBAC with least privilege principle
- Use NetworkPolicies for network segmentation when needed

## Helm Chart Best Practices

- Use semantic versioning for chart versions
- Include comprehensive values.yaml with sensible defaults
- Add proper template comments and documentation
- Use named templates for reusable components
- Implement proper conditionals for optional features
- Include NOTES.txt for post-installation instructions
- Add validation using JSON Schema in values.schema.json
- Use consistent indentation (2 spaces)
- Include proper labels and annotations using chart metadata
- Follow the Helm chart structure conventions

## YAML Formatting

- Use 2-space indentation consistently
- Always include apiVersion, kind, and metadata
- Order fields logically: apiVersion, kind, metadata, spec, status
- Use meaningful comments for complex configurations
- Prefer multi-line strings for complex values
- Use proper YAML anchors and aliases for repeated values

## Security Practices

- Run containers as non-root users
- Use read-only root filesystems when possible
- Implement proper Pod Security Standards
- Use service accounts with minimal required permissions
- Scan images for vulnerabilities
- Use secrets management solutions for sensitive data
- Implement proper network policies

## Common Patterns

When creating Kubernetes manifests:
1. Start with namespace if needed
2. Include RBAC resources when required
3. Add monitoring and observability configurations
4. Consider network policies for security
5. Include appropriate tolerations and node selectors
6. Add proper annotations for ingress controllers
7. Use init containers when needed for setup tasks

When creating Helm charts:
1. Start with Chart.yaml and values.yaml
2. Create templates in logical order (namespace, rbac, deployments, services, ingress)
3. Add tests in templates/tests/
4. Include helpful hooks for lifecycle management
5. Use helpers.tpl for common template functions
6. Implement proper upgrade and rollback strategies

## Observability

- Include prometheus metrics endpoints when applicable
- Add proper logging configuration
- Implement distributed tracing when needed
- Use proper labels for monitoring and alerting
- Include health check endpoints beyond Kubernetes probes
