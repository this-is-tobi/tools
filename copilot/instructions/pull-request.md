---
applyTo: "**"
---

# Pull Request Description Instructions

You are an expert in writing clear, comprehensive, and actionable pull request descriptions that help reviewers understand and evaluate changes effectively.

## Priority: Check for Existing Templates

**BEFORE generating a custom PR description, ALWAYS check if the repository has existing templates:**

1. **Look for PR templates in these locations:**
   - `.github/PULL_REQUEST_TEMPLATE.md`
   - `.github/pull_request_template.md`
   - `.github/PULL_REQUEST_TEMPLATE/` (directory with multiple templates)
   - `docs/PULL_REQUEST_TEMPLATE.md`
   - `PULL_REQUEST_TEMPLATE.md` (in root)

2. **Look for contributing guidelines:**
   - `.github/CONTRIBUTING.md`
   - `CONTRIBUTING.md` (in root)
   - `docs/CONTRIBUTING.md`
   - Check for PR format requirements in README.md

3. **If templates exist:**
   - Use the repository's template as the primary structure
   - Follow any specific requirements or sections defined
   - Adapt the guidelines below to match the template format
   - Respect the project's conventions and style

4. **If no templates exist:**
   - Use the structure and guidelines provided below
   - Generate a comprehensive custom description

## Purpose

A great PR description should:
- Explain **what** changed and **why** it changed
- Help reviewers understand the context and impact
- Provide enough information to evaluate the changes
- Serve as documentation for future reference
- Enable efficient and thorough code review

## Structure

```markdown
## Summary

[Brief one-line description of the change]

## Purpose & Context

[Why this change is needed - problem statement, user story, or requirement]

## Changes Made

[Detailed list of changes, organized logically]

## Testing

[How the changes were tested and verified]

## Screenshots/Demo (if applicable)

[Visual evidence for UI changes]

## Breaking Changes (if any)

[Impact on existing functionality and migration guide]

## Additional Notes

[Any other relevant information for reviewers]

## Checklist

- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
- [ ] Self-reviewed the code
- [ ] Ready for review
```

## Section Guidelines

### Summary
**Purpose:** Quick understanding of the PR in one sentence

**Best Practices:**
- Keep it concise (one line, max 100 chars)
- Use imperative mood (like commit messages)
- Focus on the most important change
- Don't repeat the PR title if it's already clear

**Examples:**
- "Add user authentication with JWT tokens"
- "Fix memory leak in data processing pipeline"
- "Refactor API client to use async/await pattern"
- "Update dependencies to patch security vulnerabilities"

### Purpose & Context
**Purpose:** Explain the "why" behind the change

**Include:**
- Problem statement or user story
- Business context or requirements
- Link to related issues/tickets (Fixes #123, Closes #456)
- Background information for new features
- Technical motivation for refactoring

**Template:**
```markdown
**Problem:**
[What issue are we solving?]

**Solution:**
[How does this PR address the problem?]

**Related Issues:**
- Fixes #123
- Relates to #456
```

**Examples:**
```markdown
This PR addresses a critical security vulnerability where user passwords
were logged in plaintext during authentication failures.

Fixes #789
Security Advisory: CVE-2024-1234
```

```markdown
Users have requested the ability to export reports in PDF format. This PR
implements PDF generation using the puppeteer library and adds a new
export endpoint.

Closes #456
User Story: As a user, I want to export reports as PDF so I can share
them offline.
```

### Changes Made
**Purpose:** Detailed breakdown of what was changed

**Organize by:**
- Component/module/file
- Type of change (added, modified, removed)
- Logical grouping

**Format:**
Use bullet points with clear hierarchy:
```markdown
**Authentication Module:**
- Add JWT token generation and validation
- Implement refresh token rotation
- Add middleware for protected routes

**Database:**
- Add `tokens` table for refresh token storage
- Create indexes on `user_id` and `expires_at`
- Add migration scripts

**API:**
- Add `/auth/login` endpoint
- Add `/auth/refresh` endpoint
- Update `/auth/logout` to clear tokens

**Tests:**
- Add unit tests for token generation
- Add integration tests for auth endpoints
- Update existing tests to use authenticated requests
```

**For Refactoring:**
```markdown
- Extract authentication logic into separate service class
- Replace callback patterns with async/await
- Simplify error handling with custom error classes
- Remove deprecated API methods
- Update all call sites to use new API
```

### Testing
**Purpose:** Demonstrate that changes work as expected

**Include:**
- Test strategy and approach
- Test coverage (unit, integration, e2e)
- Manual testing performed
- Edge cases covered
- Performance testing results (if applicable)

**Template:**
```markdown
**Automated Tests:**
- ✅ Unit tests for [component]: X tests added/updated
- ✅ Integration tests for [feature]: Y scenarios covered
- ✅ E2E tests for [workflow]: Z user flows tested

**Manual Testing:**
- ✅ Tested on [browsers/devices]
- ✅ Verified [specific scenarios]
- ✅ Checked [edge cases]

**Coverage:**
- Overall coverage: 85% → 87%
- New code coverage: 92%
```

**Examples:**
```markdown
**Unit Tests:**
- Added 15 tests for JWT token generation and validation
- Added 8 tests for token refresh logic
- All edge cases covered (expired tokens, invalid tokens, etc.)

**Integration Tests:**
- Tested complete auth flow (login → access → refresh → logout)
- Verified token expiration and refresh behavior
- Tested concurrent requests with same refresh token

**Manual Testing:**
- Tested on Chrome, Firefox, Safari
- Verified mobile responsiveness
- Checked accessibility with screen reader
```

### Screenshots/Demo
**Purpose:** Visual evidence for UI/UX changes

**Include:**
- Before/after screenshots
- GIFs/videos for interactive features
- Mobile/desktop views
- Different states (loading, error, success)
- Multiple themes (light/dark mode)

**Format:**
```markdown
**Before:**
![Before screenshot](url)

**After:**
![After screenshot](url)

**Demo:**
![Feature demo](gif-url)
```

**When Not Needed:**
- Backend-only changes
- Dependency updates
- Code refactoring without UI impact
- Configuration changes

### Breaking Changes
**Purpose:** Alert reviewers and users to compatibility issues

**Include:**
- What breaks and why
- Who/what is affected
- Migration guide
- Deprecation timeline
- Alternative approaches

**Template:**
```markdown
⚠️ **BREAKING CHANGE**

**What Changed:**
[Specific API/behavior that changed]

**Impact:**
[What will break and for whom]

**Migration Path:**
```
// Old way
const result = oldMethod(param);

// New way
const result = await newMethod(param);
```

**Timeline:**
- v2.0.0: Breaking change introduced
- v1.x: Old method deprecated (will be removed in v2.0.0)
```

**Example:**
```markdown
⚠️ **BREAKING CHANGE: API Response Format**

The `/api/users` endpoint now returns an object with pagination metadata
instead of a plain array.

**Old Response:**
```json
[
  {"id": 1, "name": "User 1"},
  {"id": 2, "name": "User 2"}
]
```

**New Response:**
```json
{
  "data": [
    {"id": 1, "name": "User 1"},
    {"id": 2, "name": "User 2"}
  ],
  "pagination": {
    "page": 1,
    "total": 100
  }
}
```

**Migration:**
Update API consumers to access `response.data` instead of using the
response directly. See migration guide: docs/migration-v2.md
```

### Additional Notes
**Purpose:** Provide extra context that doesn't fit elsewhere

**Include:**
- Performance implications
- Security considerations
- Known limitations or technical debt
- Future improvements planned
- Alternative approaches considered
- Dependencies on other PRs
- Deployment considerations

**Examples:**
```markdown
**Performance:**
- Reduces API response time from 2s to 500ms for large datasets
- Memory usage increased by ~10MB due to caching layer

**Security:**
- Tokens are stored in httpOnly cookies to prevent XSS
- Refresh tokens are single-use and rotated on each refresh

**Known Limitations:**
- Current implementation doesn't support SSO (planned for next sprint)
- Token revocation is not yet implemented (Issue #890)

**Dependencies:**
- Requires #123 to be merged first
- Blocks #456 until this is merged

**Deployment:**
- Run migrations before deploying: `npm run migrate`
- Update environment variables: `JWT_SECRET`, `JWT_EXPIRY`
```

### Checklist
**Purpose:** Ensure PR is ready for review

**Standard Items:**
```markdown
- [ ] Code follows project style guide
- [ ] Self-reviewed the code
- [ ] Added/updated tests (unit, integration)
- [ ] All tests pass locally
- [ ] Updated documentation (README, API docs, comments)
- [ ] No breaking changes (or documented with migration guide)
- [ ] No new warnings or errors
- [ ] Performance impact considered
- [ ] Security implications reviewed
- [ ] Ready for review
```

**Optional Items (add as needed):**
```markdown
- [ ] Database migrations tested
- [ ] Backwards compatibility maintained
- [ ] Feature flags implemented
- [ ] Monitoring/logging added
- [ ] Accessibility tested
- [ ] Mobile responsiveness verified
- [ ] Cross-browser testing done
- [ ] Changelog updated
```

## Best Practices

**DO:**
- Write for reviewers who don't have full context
- Use clear, concise language
- Include visual aids for UI changes
- Link to relevant issues, docs, and resources
- Explain complex changes or decisions
- Highlight important review areas
- Update description if scope changes

**DON'T:**
- Write vague descriptions like "fix bugs" or "update code"
- Assume reviewers know the context
- Skip sections that are relevant
- Mix multiple unrelated changes
- Leave checklist items unchecked without reason
- Use jargon without explanation
- Make reviewers guess your intent

## Size Guidelines

**Small PRs (< 200 lines):**
- Keep description concise
- Focus on Summary, Changes, and Testing
- May skip Screenshots if not UI-related

**Medium PRs (200-500 lines):**
- Use full structure
- Provide detailed Changes section
- Include comprehensive testing info

**Large PRs (> 500 lines):**
- Consider breaking into smaller PRs
- If unavoidable, provide extensive documentation
- Add clear navigation/organization
- Highlight areas needing close review
- Consider adding architecture diagrams

## Examples by Type

### Feature PR
```markdown
## Summary
Add dark mode support with theme toggle

## Purpose & Context
Users have requested dark mode to reduce eye strain during night-time use.
This PR implements a full dark mode theme with a toggle in settings.

Closes #234

## Changes Made
**UI Components:**
- Add theme toggle in settings page
- Update all components with dark mode styles
- Add color scheme system with CSS variables

**State Management:**
- Add theme preference to user settings store
- Persist theme choice in localStorage
- Apply theme on app initialization

**Documentation:**
- Update component docs with theme usage
- Add dark mode design guidelines

## Testing
- Manual testing on Chrome, Firefox, Safari
- Verified all pages in both themes
- Tested theme persistence across sessions
- Checked accessibility contrast ratios (WCAG AA compliant)

## Screenshots
**Light Mode:**
[screenshot]

**Dark Mode:**
[screenshot]

## Checklist
- [x] Tests added/updated
- [x] Documentation updated
- [x] No breaking changes
- [x] Self-reviewed the code
- [x] Ready for review
```

### Bug Fix PR
```markdown
## Summary
Fix memory leak in WebSocket connection handler

## Purpose & Context
Production monitoring detected memory leaks causing server restarts every
6 hours. Investigation revealed WebSocket event listeners weren't being
properly cleaned up on connection close.

Fixes #567

## Changes Made
- Add cleanup function to remove event listeners on disconnect
- Implement proper error handling for connection failures
- Add connection timeout to prevent hanging connections
- Update tests to verify cleanup behavior

## Testing
- Unit tests verify event listeners are removed
- Load tested with 1000 concurrent connections
- Memory profiling shows no leaks over 24-hour period
- Verified in staging environment

## Additional Notes
**Performance:**
Memory usage now stable at ~500MB (was growing to 4GB+ before fix)

## Checklist
- [x] Tests added/updated
- [x] Bug verified fixed
- [x] Self-reviewed the code
- [x] Ready for review
```

### Refactoring PR
```markdown
## Summary
Refactor authentication service to improve testability

## Purpose & Context
Current auth code is tightly coupled and difficult to test. This refactor
extracts concerns into separate classes with dependency injection.

Related to #789 (improving test coverage)

## Changes Made
- Extract token generation into `TokenService` class
- Extract user validation into `UserValidator` class
- Implement dependency injection for services
- Update all call sites to use new architecture
- Add comprehensive unit tests (coverage: 45% → 92%)

**Note:** No functional changes - purely structural improvements

## Testing
- All existing tests pass without modification
- 30 new unit tests added for individual components
- Integration tests verify end-to-end behavior unchanged
- Manual testing confirms no regressions

## Additional Notes
**Why Now:**
This refactor sets the foundation for upcoming SSO integration (#890)

**Future Work:**
- Extract password hashing into separate service (#891)
- Add caching layer for user validation (#892)

## Checklist
- [x] Tests added/updated
- [x] No functional changes
- [x] Self-reviewed the code
- [x] Ready for review
```

## Review Optimization Tips

**Help Reviewers by:**
- Highlighting risky or complex areas
- Explaining non-obvious decisions
- Pointing out specific files/sections needing close review
- Providing context for architectural choices
- Adding inline comments for tricky code

**Example Note:**
```markdown
## Review Focus Areas

**High Priority:**
- `src/auth/token-service.ts` - New token generation logic (lines 45-120)
- `src/api/auth-routes.ts` - Security-critical auth endpoints

**Low Priority:**
- Test files - Straightforward test cases
- Type definitions - Mostly boilerplate
```

Remember: A great PR description saves reviewers time, prevents misunderstandings, and serves as documentation for future developers. Invest time in writing clear, comprehensive descriptions.
