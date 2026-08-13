# OpenCode-specific rules

These instructions extend the shared global agent rules with OpenCode-specific
behavior.

## Review before commit

Use the `@review` agent before committing when one or more of these conditions
apply:

- Two or more files changed.
- A feature or module was added.
- Existing behavior was changed or refactored.
- A public interface, export, or option changed.

If the review finds issues, fix them and verify the result before committing.
Single-file wording, comment-only, documentation-only, and formatting-only
changes do not require this review.

## Planning interface

- For complex changes, submit the plan through the `submit_plan` tool.
- Do not implement the change until the plan is approved.
- Revise the plan when the user provides feedback.

## Worktree workflow

- Work on the current branch unless the user explicitly requests a worktree.
- For large changes, ask whether the user wants a worktree before proceeding.
- When requested, create a dedicated branch and worktree, create the PR from
  that branch, and remove the worktree after merge.

## Code review

- Focus on readability, maintainability, security, and performance.
- Explain findings constructively and check edge cases, error handling, and
  alignment with existing patterns.

## Custom agents

Use the appropriate custom agent for specialized tasks:

- `@review`: Review code quality, best practices, potential bugs, and security
  without making direct changes.
- `@troubleshoot`: Analyze error logs and stack traces, identify likely root
  causes, and propose fixes.

## Prompt keywords

When the user's message contains the keyword `webs`, case-insensitively and
usually at the end, remove the keyword from the task and apply aggressive web
search throughout the work. Search before writing code or making decisions,
verify APIs and current documentation, prefer current sources over model memory,
and search at least three times.

## Skills

- Load `/git-commit` when creating commits.
- Load `/git-pr` when creating GitHub pull requests.
