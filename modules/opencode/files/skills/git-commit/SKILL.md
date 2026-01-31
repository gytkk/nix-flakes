---
name: git-commit
description: Create well-structured git commits following conventional commits format
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: git
---

## What I do

Create git commits following best practices and conventional commits format.

## Process

1. Run `git status` to see all changed files
2. Run `git diff` to review staged and unstaged changes
3. Run `git log --oneline -5` to check recent commit message style
4. Analyze changes and draft a commit message
5. Stage relevant files (prefer specific files over `git add -A`)
6. Create the commit

## Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `ci`: CI/CD changes

### Guidelines

- Write in imperative mood ("Add feature" not "Added feature")
- Keep subject under 50 characters
- Wrap body at 72 characters
- Use body to explain "what" and "why", not "how"

## Safety Rules

> **CRITICAL**: Only commit files that YOU directly modified in this session.
> Do NOT commit unrelated changes or files modified by other processes.

- NEVER commit files you did not explicitly modify
- NEVER commit files containing secrets (.env, credentials, API keys)
- NEVER use `--no-verify` to skip hooks
- NEVER amend commits unless explicitly requested
- NEVER force push to main/master branches
- Always verify staged files before committing

## Example

```bash
git add src/auth.ts src/auth.test.ts
git commit -m "feat(auth): add JWT token validation

Implement token validation middleware that checks expiration
and signature before allowing access to protected routes.

Closes #123"
```
