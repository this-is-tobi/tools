---
applyTo: "**"
---

# Commit Message Instructions

You are an expert in writing clear, concise, and meaningful commit messages following the Conventional Commits specification.

## Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

## Rules

**Structure:**
- **type**: Required (lowercase)
- **scope**: Optional (lowercase, in parentheses)
- **subject**: Required (lowercase, no period, max 72 chars)
- **body**: Optional (wrap at 72 chars, explain what and why)
- **footer**: Optional (breaking changes, issues, etc.)

**Type Values:**
- `feat`: New feature for the user
- `fix`: Bug fix for the user
- `docs`: Documentation changes
- `style`: Formatting, missing semicolons, etc. (no code change)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependency updates
- `ci`: CI/CD configuration changes
- `build`: Build system or external dependencies
- `revert`: Reverting a previous commit

**Scope Examples:**
- `api`, `auth`, `database`, `ui`, `config`
- `user`, `payment`, `notification`
- Component/module/file name
- Keep it short and meaningful

## Best Practices

**Commit Scope & History:**
- Make commits **focused and atomic** - one logical change per commit
- Squash related "fix typo" or "address review" commits before merging
- Each commit should be **meaningful and reviewable** on its own
- Maintain **precise history** - avoid mixing unrelated changes
- Think: "Can I revert this commit independently if needed?"
- Group related changes logically but keep them separate if they serve different purposes

**Subject Line:**
- Start with lowercase
- Use imperative mood ("add" not "added" or "adds")
- No period at the end
- Be specific and concise
- Max 72 characters

**Body (when needed):**
- Explain what changed and why (not how)
- Wrap at 72 characters per line
- Separate from subject with blank line
- Use bullet points for multiple changes
- Reference issues when relevant

**Footer:**
- `BREAKING CHANGE:` for breaking changes
- `Closes #123` or `Fixes #456` for issues
- `Co-authored-by:` for attribution

## Examples

**Simple feature:**
```
feat(auth): add password reset functionality
```

**Bug fix with scope:**
```
fix(api): resolve null pointer in user endpoint
```

**Breaking change:**
```
feat(api)!: change user endpoint response format

BREAKING CHANGE: The user endpoint now returns an object instead of an array.
Migration guide: https://docs.example.com/migration
```

**With body and footer:**
```
feat(payment): integrate stripe payment gateway

- Add stripe SDK integration
- Implement payment processing flow
- Add webhook handlers for payment events

Closes #234
```

**Multiple types scenario - choose the primary:**
```
feat(dashboard): add user analytics with tests

Implement analytics dashboard showing user activity metrics.
Tests cover all new components and data fetching logic.
```

**Refactoring:**
```
refactor(auth): simplify token validation logic

Extract validation into separate function for better testability
and reduced complexity.
```

**Documentation:**
```
docs(readme): update installation instructions

Add instructions for Docker setup and environment configuration.
```

**Dependency update:**
```
chore(deps): update dependencies to latest versions

- Update react from 18.2.0 to 18.3.0
- Update typescript from 5.0.0 to 5.2.0
```

**CI/CD changes:**
```
ci(github): add automated security scanning

Integrate dependabot and CodeQL for vulnerability detection.
```

**Performance improvement:**
```
perf(database): optimize user query with indexes

Add composite index on (email, status) to reduce query time
from 2s to 50ms for large datasets.
```

**Revert:**
```
revert: feat(api): add new authentication method

This reverts commit abc123def456.
Reason: Breaking changes detected in production.
```

## Common Mistakes to Avoid

❌ **Don't:**
- Use past tense: "added feature"
- Be vague: "fix bug" or "update code"
- Capitalize subject: "Add Feature"
- End subject with period: "add feature."
- Mix multiple unrelated changes in one commit
- Write too long subjects (>72 chars)
- Forget scope when it adds clarity

✅ **Do:**
- Use imperative: "add feature"
- Be specific: "fix null pointer in user service"
- Keep it concise and clear
- Group related changes logically
- Reference issues in footer
- Use body for context when needed

## Quick Decision Guide

**Choose the type:**
1. Adding functionality? → `feat`
2. Fixing a bug? → `fix`
3. Changing docs only? → `docs`
4. Code cleanup/restructure? → `refactor`
5. Improving performance? → `perf`
6. Tests only? → `test`
7. CI/build/deps? → `ci`/`build`/`chore`

**Add scope if:**
- Multiple modules exist in the project
- The change is isolated to one area
- It adds clarity without being obvious

**Add body if:**
- The "why" isn't obvious from the subject
- Multiple related changes were made
- Context or rationale is needed
- Breaking changes need explanation

**Add footer if:**
- Closes/fixes an issue
- Contains breaking changes
- Multiple authors contributed
- Needs special notation

## Verification Checklist

Before committing, verify:
- [ ] Type is valid and appropriate
- [ ] Subject is imperative, lowercase, no period
- [ ] Subject is under 72 characters
- [ ] Scope adds value (if used)
- [ ] Body explains "what" and "why" (if needed)
- [ ] Breaking changes are documented
- [ ] Related issues are referenced
- [ ] Message is clear and meaningful

Remember: A good commit message explains the change to your future self and team members who weren't involved in the development.
