---
name: pull-request
description: Generate comprehensive pull request descriptions. Use when asked to write a PR description, create a pull request, or describe changes for a PR.
---

# Pull Request Description

Generate clear, comprehensive PR descriptions that help reviewers understand and evaluate changes.

## Priority: Check for Templates First

Before generating a custom description, check for existing PR templates:
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/pull_request_template.md`
- `.github/PULL_REQUEST_TEMPLATE/` (directory)
- `PULL_REQUEST_TEMPLATE.md` (root)

If templates exist, use them. Otherwise, check for organization-level templates in the `.github` repository. And if there are no templates, generate a custom description using the structure below.

## Structure

```markdown
## Summary

[One-line description of the change]

## Purpose & Context

**Problem:** [What issue are we solving?]
**Solution:** [How does this PR address it?]
**Related Issues:** Fixes #123, Relates to #456

## Changes Made

**[Module/Component]:**
- Change 1
- Change 2

**Tests:**
- Unit tests added/updated
- Integration tests for critical paths

## Testing

**Automated:** ✅ Unit (X tests) · ✅ Integration (Y scenarios)
**Manual:** ✅ Tested on [browsers/devices/environments]
**Coverage:** X% → Y%

## Screenshots/Demo (if applicable)

[Before/after screenshots or GIFs for UI changes]

## Breaking Changes (if any)

⚠️ [What changed, who is affected, migration path]

## Additional Notes

[Performance, security, known limitations, deployment considerations]

## Checklist

- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
- [ ] Self-reviewed the code
- [ ] Ready for review
```

## Section Guidelines

**Summary:** One line, max 100 chars, imperative mood, focus on the most important change.

**Purpose & Context:** Explain "why", link issues/tickets, include business context.

**Changes Made:** Organize by component, use bullet hierarchy, include both code and test changes.

**Testing:** List automated + manual testing, specify coverage delta.

**Breaking Changes:** Include what breaks, who is affected, and a migration guide with code examples.

## Size Guidelines

| Size | Lines Changed | Review Time |
|---|---|---|
| Small | < 100 | < 30 min |
| Medium | 100-400 | 30-90 min |
| Large | 400-1000 | > 90 min |
| Too Large | > 1000 | Split the PR |

Prefer small, focused PRs. If a PR is large, explain why it cannot be split.
