---
name: git-pr
description: Create GitHub pull requests with proper descriptions and context
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: github
---

## What I do

Create GitHub pull requests with comprehensive descriptions using the `gh` CLI.

## Process

1. Run `git status` to check current branch state
2. Run `git log main..HEAD --oneline` to see all commits in this branch
3. Run `git diff main...HEAD` to understand full changes
4. Check if branch is pushed to remote
5. Create PR with structured description

## PR Description Format

```markdown
## Summary

- Brief bullet points of what this PR does
- Focus on the "why" not just the "what"

## Changes

- List of specific changes made
- Group by component or area

## Test Plan

- [ ] How to verify these changes work
- [ ] Edge cases considered

---
🤖 Generated with OpenCode
```

## Commands

```bash
# Check current state
git status
git log main..HEAD --oneline
git diff main...HEAD --stat

# Push branch if needed
git push -u origin <branch-name>

# Create PR
gh pr create --title "feat: add user authentication" --body "$(cat <<'EOF'
## Summary

- Add JWT-based authentication for API endpoints
- Implement login/logout functionality

## Test Plan

- [ ] Test login with valid credentials
- [ ] Test login with invalid credentials
- [ ] Verify token expiration handling

---
🤖 Generated with OpenCode
EOF
)"
```

## Guidelines

- Keep PR title under 70 characters
- Use conventional commit format for title
- Include all relevant commits in description analysis
- Link related issues when applicable
- Add reviewers if specified

## Safety Rules

- NEVER create PRs to main/master without explicit request
- NEVER include sensitive information in PR descriptions
- Always verify the target branch before creating PR
- Check CI status after PR creation
