---
applyTo: "**"
---

# Code Review Guidelines

When reviewing code, follow these priorities:

**🔴 CRITICAL (Must Fix)** — Security vulnerabilities, bugs causing crashes/data loss, resource leaks, race conditions, injection attacks.

**🟡 HIGH (Should Fix)** — Performance bottlenecks, missing error handling, SOLID violations, missing tests for critical paths.

**🟢 MEDIUM** — Style inconsistencies, naming improvements, refactoring opportunities, missing edge case handling.

**🔵 LOW** — Additional test coverage, documentation enhancements, micro-optimizations.

## Core Checks

- **Correctness**: Logic errors, edge cases, null handling, type safety
- **Security**: Input validation, parameterized queries, secrets management, auth checks
- **Performance**: N+1 queries, missing caching, blocking async, missing indexes
- **Testing**: Coverage, isolation, edge cases, error paths
- **Quality**: SOLID, DRY, complexity < 10, clear naming
- **Error handling**: Meaningful messages, logging with context, resource cleanup

## Output

Structure reviews as: **Summary** → **Critical Issues (🔴)** → **Important Issues (🟡)** → **Suggestions (🟢/🔵)** → **Positive Feedback** → **Questions**.

For detailed review methodology including language-specific checks, anti-patterns, and decision frameworks, use the `code-review` skill.
