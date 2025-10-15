# Development Guidelines

Expert-level development instructions covering all aspects of modern software development.

## General Principles

**Code Quality**
- Write clean, maintainable, self-documenting code following SOLID principles
- Use meaningful names; keep functions small and focused
- Avoid duplication (DRY); refactor regularly
- Comment only to explain "why", not "what"

**Version Control**
- Use conventional commits with semantic versioning
- Make small, focused commits with meaningful messages
- Use proper branching strategies (Git Flow/GitHub Flow)
- Write descriptive PR descriptions; keep commit history clean

**Security**
- Validate and sanitize all inputs; use parameterized queries
- Follow least privilege principle; handle secrets securely
- Keep dependencies updated; implement SAST scanning
- Log properly without exposing sensitive data

**Testing**
- Write unit tests for business logic; maintain good coverage
- Implement integration tests for critical paths
- Use TDD when appropriate; write maintainable tests
- Implement performance testing for critical components

**Documentation**
- Maintain up-to-date READMEs with setup procedures
- Document APIs comprehensively with examples
- Include troubleshooting guides; document architectural decisions
- Keep documentation close to code

## Shell Scripts

**Best Practices**
- Use `#!/bin/bash` or `#!/usr/bin/env bash` shebang
- Always use `set -euo pipefail` for strict error handling
- Quote all variables: `"$variable"` not `$variable`
- Use `[[ ]]` instead of `[ ]` for conditionals
- Use lowercase for local vars, UPPERCASE for environment vars
- Use `readonly` for constants; initialize variables before use

**Structure & Error Handling**
- Include header with script purpose and usage
- Define variables at top; use functions for reusable code
- Implement proper argument parsing with help/usage info
- Use trap for cleanup operations; check return codes explicitly
- Provide meaningful error messages with context

**Security & Performance**
- Validate all inputs; use `mktemp` for temporary files
- Set proper file permissions; avoid eval and shell injection
- Use full paths for commands; use built-ins over external commands
- Avoid unnecessary subshells; process large files line by line

## Docker

**Dockerfile Best Practices**
- Use official base images with specific tags (not `latest`)
- Minimize layers by combining RUN commands
- Use multi-stage builds; order by change frequency
- Run as non-root users; use .dockerignore effectively
- Use COPY over ADD; implement health checks

**Security & Optimization**
- Scan images regularly; use minimal bases (Alpine, distroless)
- Don't include secrets; use read-only filesystems when possible
- Clean up package caches; use BuildKit features
- Implement proper resource limits and restart policies

**Production**
- Use orchestration (Kubernetes); implement monitoring
- Use proper registries with access controls
- Implement vulnerability scanning and proper CI/CD
- Use proper backup/disaster recovery strategies

## Kubernetes & Helm

**Kubernetes Guidelines**
- Use latest stable API versions; prefer Deployments over bare Pods
- Include resource requests/limits; add proper labels/selectors
- Use meaningful DNS-1035 names; implement health checks
- Use ConfigMaps/Secrets; follow RBAC least privilege
- Implement NetworkPolicies; run containers as non-root

**Helm Best Practices**
- Use semantic versioning; provide sensible defaults
- Include comprehensive documentation; use named templates
- Implement conditionals for features; add validation schemas
- Use 2-space indentation; include NOTES.txt
- Follow chart structure conventions

**YAML Standards**
- Use 2-space indentation consistently
- Order: apiVersion, kind, metadata, spec, status
- Use meaningful comments; prefer multi-line strings
- Include proper labels for monitoring

## GitHub Actions

**Workflow Best Practices**
- Use descriptive names; organize logically (CI/CD/security)
- Use proper triggers; implement branch protection
- Break into focused jobs with proper dependencies
- Use conditional execution; implement proper timeouts

**Security**
- Use GITHUB_TOKEN with minimal permissions
- Store sensitive data in Secrets; use OIDC when possible
- Pin action versions to commits/tags
- Use only trusted verified actions

**Performance**
- Cache dependencies/artifacts; use matrix strategies
- Optimize Docker builds with layer caching
- Use self-hosted runners when needed
- Implement proper cleanup

**Common Actions**
- `actions/checkout@v4`, `actions/setup-node@v4`
- `actions/cache@v4`, `actions/upload-artifact@v4`
- `docker/build-push-action@v5`

## JavaScript & TypeScript

**TypeScript Guidelines (STRICT)**
- Always use strict mode; avoid `any`, prefer `unknown`
- Prefer interfaces over types for objects
- Always define return types; use readonly for immutable data
- Leverage utility types; use zod for validation/inference
- Use discriminated unions for complex state

**Modern Patterns**
- Use ES6+ features (async/await, destructuring, arrow functions)
- Prefer functional patterns; use ESM imports/exports
- Use const over let; avoid var completely
- Implement proper async/await error handling

**Code Quality**
- Use camelCase for variables/functions, PascalCase for classes/types
- Include JSDoc for public APIs; follow SOLID principles
- Check for existing functions before implementing new ones
- Keep functions <20 lines, components <200, files <300
- Keep cyclomatic complexity <10; avoid circular dependencies

**Testing**
- Use `<filename>.spec.ts` naming; follow AAA pattern
- Aim for 90%+ coverage; write unit tests alongside code
- Mock external dependencies; use TDD when appropriate
- Keep tests isolated and independent

**Node.js Specific**
- Use latest LTS version; use async/await for async ops
- Implement graceful shutdown; use structured logging
- Handle uncaught exceptions/rejections
- Use proper middleware patterns (Fastify)
- Implement rate limiting and security headers

**Frontend Specific**
- Implement a11y best practices; use semantic HTML
- Optimize for Core Web Vitals; use proper CSP headers
- Follow responsive/mobile-first design
- Use proper state management (Pinia for Vue)

**API Development**
- Use OpenAPI/Swagger for docs; validate requests
- Use proper HTTP status codes and error formats
- Implement authentication/authorization
- Use versioning (`/api/v1/resource`); paginate large datasets

## Go

**Best Practices**
- Follow Effective Go guidelines; use gofmt/golint/go vet
- Use meaningful short lowercase package names
- Prefer composition over inheritance
- Handle errors explicitly with context
- Use context.Context for cancellation/timeouts

**Code Organization**
- Organize in packages with clear responsibilities
- Use internal/ for private code; use pkg/ for libraries
- Use cmd/ for entry points; keep main packages small

**Error Handling**
- Always check errors; use meaningful messages with context
- Wrap errors with `fmt.Errorf` and `%w`
- Create custom error types when needed
- Use `errors.Is` and `errors.As` for checking

**Concurrency**
- Use goroutines for concurrency; use channels for communication
- Use context for cancellation; avoid shared mutable state
- Use sync.WaitGroup for waiting; implement graceful shutdowns

**Testing & Performance**
- Write table-driven tests; use testify when needed
- Implement integration tests; achieve good coverage
- Use pprof for profiling; implement proper caching
- Use buffered I/O appropriately

## TypeScript Monorepo

**Critical Guidelines**
- Use strict TypeScript (mandatory); never use `any`
- Follow ESLint rules meticulously; fix all warnings
- Maintain 90%+ unit test coverage
- Keep codebase clean; remove unused code/dependencies

**Tools**
- proto for version management; pnpm as package manager
- turbo for monorepo management; vite for frontend
- eslint with @antfu/eslint-config (no prettier)
- vitest for unit tests; playwright for e2e
- fastify for APIs; vue for frontend
- zod for validation; prisma as ORM
- pino for logging; better-auth for auth

**Project Structure**
```
apps/           # Applications (api, web, docs)
packages/       # Shared packages (utils, schemas, types)
ci/             # CI/CD configs
scripts/        # Automation scripts
tests/          # Integration/e2e tests
```

**Deployment**
- Keep stateless for Kubernetes; use environment variables
- Implement health checks; use containerization
- Track metrics with Prometheus/Grafana

**Task Flow**
- Pull from main; evaluate current state; avoid duplication
- Update types/schemas/tests; check linting/building/tests
- Use conventional commits; push to dedicated branch
- Open PR with detailed description

## Performance & Monitoring

**Optimization**
- Profile before optimizing; use appropriate data structures
- Implement caching; optimize queries/indexes
- Use async programming properly; monitor performance
- Consider scalability from start

**Observability**
- Implement comprehensive structured logging
- Add metrics for key indicators; use distributed tracing
- Set up proper alerting; use health checks
- Monitor resource usage; implement error tracking

## Configuration & Dependencies

**Management**
- Use environment-specific config; keep config separate from code
- Use environment variables for sensitive data
- Implement validation; document options
- Version configuration changes

**Dependencies**
- Keep updated; scan for vulnerabilities
- Pin versions in production; audit regularly
- Remove unused dependencies; choose carefully
- Monitor licenses; have upgrade strategy
