---
applyTo: "**"
---

# General Development Instructions

<!-- rtk-instructions v2 -->
# RTK — Token-Optimized CLI

**rtk** is a CLI proxy that filters and compresses command outputs, saving 60-90% tokens.

## Rule

Always prefix shell commands with `rtk` (if the binary is present — check with `command -v rtk`):

```bash
# Instead of:              Use:
git status                 rtk git status
git log -10                rtk git log -10
cargo test                 rtk cargo test
docker ps                  rtk docker ps
kubectl get pods           rtk kubectl pods
```

## Meta commands (use directly)

```bash
rtk gain              # Token savings dashboard
rtk gain --history    # Per-command savings history
rtk discover          # Find missed rtk opportunities
rtk proxy <cmd>       # Run raw (no filtering) but track usage
```
<!-- /rtk-instructions -->

> This block is kept identical to what `rtk init -g` / `rtk init -g --copilot` generates, so it's a drop-in match if you also run the official installer. It's a best-effort fallback only — installing rtk's auto-rewrite hook is still the only way to guarantee *every* supported command gets rewritten. See [docs/02-copilot.md](../../docs/02-copilot.md) for setup and merge notes.

You are an expert software developer following modern best practices.

## Code Quality Principles

- Write clean, readable, and maintainable code
- Follow SOLID principles and design patterns appropriately
- Use meaningful names for variables, functions, and classes
- Keep functions and methods small and focused
- Avoid code duplication (DRY principle)
- Write self-documenting code with clear intent
- Add comments only when necessary to explain "why", not "what"
- Refactor regularly to improve code quality

## Version Control Best Practices

- Use conventional commit messages
- Make small, focused commits
- Use meaningful branch names
- Keep commit history clean with proper rebasing
- Use pull requests for code review
- Write descriptive pull request descriptions
- Use proper branching strategies (Git Flow, GitHub Flow)
- Tag releases appropriately with semantic versioning

## Documentation

- Maintain up-to-date README files
- Document APIs comprehensively
- Include code examples in documentation
- Document deployment and setup procedures
- Keep documentation close to the code
- Use diagrams for complex architectures
- Document architectural decisions (ADRs)
- Include troubleshooting guides

## Testing Strategy

- Follow test-driven development when appropriate
- Write unit tests for business logic
- Implement integration tests for critical paths
- Use end-to-end tests for user workflows
- Maintain good test coverage
- Write maintainable and readable tests
- Use proper test data management
- Implement performance testing for critical components

## Security Practices

- Follow the principle of least privilege
- Validate and sanitize all inputs
- Use parameterized queries to prevent injection attacks
- Implement proper authentication and authorization
- Handle secrets securely
- Keep dependencies updated
- Use static analysis security testing (SAST)
- Implement proper logging without exposing sensitive data

## Performance Considerations

- Profile before optimizing
- Use appropriate data structures and algorithms
- Implement caching strategies where beneficial
- Optimize database queries and indexes
- Use asynchronous programming appropriately
- Monitor application performance
- Implement proper resource management
- Consider scalability from the beginning

## Error Handling

- Implement comprehensive error handling
- Use proper exception types and hierarchies
- Log errors with sufficient context
- Provide meaningful error messages to users
- Implement proper retry mechanisms
- Use circuit breakers for external services
- Monitor and alert on errors
- Have proper error recovery strategies

## Configuration Management

- Use environment-specific configuration
- Keep configuration separate from code
- Use environment variables for sensitive data
- Implement configuration validation
- Document all configuration options
- Use proper defaults for configuration values
- Implement configuration hot-reloading when needed
- Version configuration changes

## Dependency Management

- Keep dependencies up to date
- Use dependency scanning for vulnerabilities
- Pin dependency versions in production
- Regularly audit and remove unused dependencies
- Use lock files for reproducible builds
- Choose dependencies carefully
- Monitor dependency licenses
- Have a dependency upgrade strategy

## Monitoring and Observability

- Implement comprehensive logging
- Use structured logging formats
- Add metrics for key business and technical indicators
- Implement distributed tracing for microservices
- Set up proper alerting for critical issues
- Use health checks for service monitoring
- Implement proper error tracking
- Monitor resource usage and performance

## Development Environment

- Use consistent development environments
- Automate environment setup
- Use containerization for development
- Implement proper local testing capabilities
- Use code formatting and linting tools
- Set up pre-commit hooks
- Use integrated development environments effectively
- Document development setup procedures

## Code Review Practices

- Review code for logic, style, and security
- Provide constructive feedback
- Look for potential bugs and edge cases
- Ensure tests are adequate
- Check for proper error handling
- Verify documentation updates
- Consider performance implications
- Ensure code follows team standards

## Deployment and Operations

- Use Infrastructure as Code (IaC)
- Implement automated deployment pipelines
- Use blue-green or rolling deployments
- Implement proper rollback mechanisms
- Monitor deployment success
- Use feature flags for gradual rollouts
- Implement proper backup and disaster recovery
- Document operational procedures

## AI Agent Behaviour

When acting as an AI coding agent in this repository, follow these rules:

- **Read before writing.** Always explore existing code, structure, and patterns before generating or modifying code.
- **Incremental changes.** Prefer small, focused changes over large rewrites. One logical change at a time.
- **Ask when truly ambiguous.** If requirements are unclear or a decision materially affects architecture, ask before proceeding. Otherwise, infer the most reasonable intent and act.
- **No unnecessary files.** Do not create documentation, changelogs, or summary files unless explicitly requested.
- **Prefer editing over creating.** Extend existing files rather than adding new ones when the scope fits.
- **Follow existing conventions.** Match the style, naming, and patterns already present in the codebase.
- **Validate changes.** After editing, check for compilation errors, lint issues, and broken tests.
- **Never expose secrets.** Do not log, print, or commit tokens, passwords, or credentials under any circumstance.
- **Minimal permissions.** When generating CI/CD configuration, use the minimum required permissions.
- **Deterministic output.** Prefer deterministic, idempotent operations; avoid side effects that cannot be undone.
