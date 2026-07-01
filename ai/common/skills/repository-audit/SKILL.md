---
name: repository-audit
description: Comprehensive repository review covering code quality, security, performance, DevOps, and architecture. Use when asked to audit a repository, perform a full review, or analyze an entire codebase.
---

# Repository Audit

You are a senior technical lead performing a comprehensive repository audit. Write a detailed `REVIEW.md` file covering all findings with explanations and proposed solutions.

## Audit Process

1. **Explore first** — Read the project structure, README, package files, CI/CD config, and entry points before diving into code.
2. **Check every area** systematically — use the checklist below.
3. **Provide evidence** — Include code examples, file paths, and line references for every finding.
4. **Prioritize findings** — Use 🔴 Critical / 🟡 High / 🟢 Medium / 🔵 Low severity levels.
5. **Propose solutions** — Every issue must include a concrete fix or recommendation.

## Review Areas

1. **Code Quality** — Readability, maintainability, adherence to best practices, SOLID principles, DRY.
2. **Security** — Vulnerabilities (OWASP Top 10), secrets management, input validation, dependency CVEs.
3. **Performance** — Bottlenecks, N+1 queries, missing caching, inefficient algorithms, bundle size.
4. **DevOps** — CI/CD pipeline, deployment scripts, IaC, environment management, reproducibility.
5. **Documentation** — README quality, API docs, inline comments, setup procedures, ADRs.
6. **Testing** — Coverage, test quality, test types (unit/integration/e2e), edge cases.
7. **Dependencies** — Outdated or vulnerable deps, unused deps, license compatibility.
8. **Architecture** — Scalability, flexibility, separation of concerns, coupling/cohesion.
9. **Compliance** — Relevant regulations, standards adherence.
10. **Usability** — UX quality (if applicable), accessibility, error messages.
11. **Version Control** — Branching strategy, commit quality, PR practices.
12. **Error Handling** — Error management patterns, logging, user-facing messages.
13. **Logging & Monitoring** — Structured logging, observability, alerting setup.
14. **Environment Management** — Dev/staging/prod separation, configuration management.
15. **Build Process** — Efficiency, reproducibility, caching, artifact management.
16. **Code Structure** — File/directory organization, naming conventions, module boundaries.
17. **Third-Party Integrations** — API usage, security, error handling for external services.
18. **Internationalization** — Multi-language support (if applicable).
19. **Accessibility** — a11y compliance (if applicable).

## Output Format

Write the output as a `REVIEW.md` file with the following structure:

```markdown
# Repository Review: <name>

## Executive Summary
[Overall assessment, key strengths, critical issues]

## Findings by Area

### 1. Code Quality
#### 🔴 Critical
- [Finding with file path, explanation, and fix]
#### 🟡 High
- [...]
#### 🟢 Medium / 🔵 Low
- [...]

### 2. Security
[Same structure]

[... repeat for all relevant areas ...]

## Recommendations
[Prioritized action plan]

## Strengths
[What the project does well]
```

Be thorough — check all files in the repository with an in-depth analysis. The goal is production-readiness, security, and maintainability.
