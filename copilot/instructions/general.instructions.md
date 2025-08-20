---
applyTo: "**"
---

# General Development Instructions

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
