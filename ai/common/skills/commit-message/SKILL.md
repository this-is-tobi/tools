---
name: commit-message
description: Write a commit message following the Conventional Commits specification from the staged (or described) changes. Use when asked to write, suggest or reword a commit message. It only writes the message; staging and committing stay with the user.
model: haiku
---

# Commit Message Generation

Generate clear, concise commit messages following the Conventional Commits specification.

Read the changes with `git diff --cached` (or `git diff` when nothing is staged), `git status` and `git log` for the repository's style, then output the message. Don't stage, format, commit or amend anything unless the user explicitly asks for it.

> Do not mention the AI assistant in the commit message (eg., "Co-authored-by: AI Assistant"). Instead, focus on the changes made, their purpose, and any relevant context.

## Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

## Rules

- **type**: Required, lowercase — `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`, `build`, `revert`
- **scope**: Optional, lowercase, in parentheses — module/component name
- **subject**: Required, lowercase, imperative mood, no period, max 72 chars
- **body**: Optional, wrap at 72 chars, explain what and why (not how)
- **footer**: Optional — `BREAKING CHANGE:`, `Closes #123`, `Co-authored-by:`

## Type Selection

| Question | Type |
|---|---|
| Adding functionality? | `feat` |
| Fixing a bug? | `fix` |
| Documentation only? | `docs` |
| Code cleanup/restructure? | `refactor` |
| Improving performance? | `perf` |
| Tests only? | `test` |
| CI/build/deps? | `ci` / `build` / `chore` |

## Commit Principles

- **Atomic commits** — one logical change per commit
- **Independently revertable** — each commit meaningful on its own
- **Squash noise** — merge "fix typo" / "address review" before merging
- **Never mix** unrelated changes in one commit

## Examples

```
feat(auth): add password reset functionality
```

```
fix(api): resolve null pointer in user endpoint
```

```
feat(api)!: change user endpoint response format

BREAKING CHANGE: The user endpoint now returns an object instead of an array.
```

```
feat(payment): integrate stripe payment gateway

- Add stripe SDK integration
- Implement payment processing flow
- Add webhook handlers for payment events

Closes #234
```

## Common Mistakes

- Describing unformatted or failing code — if the project has a lint/format command, mention it so the user can run it before committing
- Past tense ("added feature") — use imperative ("add feature")
- Vague messages ("fix bug", "update code") — be specific
- Capitalized subject — start lowercase
- Period at end of subject — omit it
- Subject > 72 chars — keep it concise
