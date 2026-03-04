# AGENTS.md

## Verification & Inquiry Protocol (TOP PRIORITY)

> **CRITICAL**: Apply at EVERY step. This overrides all other instructions.

- **Verify before moving on.** Confirm each step succeeded with evidence (tests, diagnostics, diffs) — never assume.
- **Ask, don't guess.** If requirements are ambiguous or context is missing, ask the user immediately.
- **Surface blockers early.** Flag missing info, risky assumptions, or dependencies NOW — not after building on them.

## Git & Commit Workflow

> **CRITICAL**: Follow the single flow from change completion through commit.

1. Complete one logical change
2. If subject to review → Use `@review` agent
   - No issues → Proceed to commit
   - Issues found → Fix and re-verify
3. If not subject to review → Commit immediately
4. Do not bundle unrelated changes into a single commit

**Review targets** (review when one or more apply):

- 2+ files modified
- New feature/module added
- Refactoring or existing behavior changes
- Public interface (API, export, option) changes

**Not subject to review**: Single-file typo/wording fixes, comment/docs-only changes, formatting-only changes

**Commit rules**:

- [Conventional Commits](https://www.conventionalcommits.org/) format (e.g., `feat:`, `fix:`, `docs:`)
- Reference git commit history to maintain consistent message style
- Imperative mood (e.g., "Add feature" not "Added feature")
- Do NOT push unless explicitly requested

## Planning & Approval

**Simple changes** (1–2 file edits, low risk, explainable in one short paragraph):

- Apply immediately → Confirm with diff and verification results

**Complex changes** (3+ files, new feature/module, cross-module, behavior-changing, public interface changes):

- Submit plan for user approval via `submit_plan` tool
- If the user provides feedback, revise the plan accordingly
- Do NOT proceed with implementation until plan is approved

## Worktree Workflow

By default, work on the current branch. Only use git worktree when the user explicitly requests it.
For large-scale changes (e.g., new features, major refactors), ask the user whether to use a worktree before proceeding.

**When worktree is requested:**

1. Create a new branch and worktree: `git worktree add ~/trees/$(basename $PWD)/<short-task-name> -b <branch-name>`
2. Change to the worktree directory and work there
3. When done, create a PR from the worktree branch
4. After merge, clean up: `git worktree remove ~/trees/$(basename $PWD)/<short-task-name>`

## Critical Rules

- First, deeply understand and think about what you want to achieve with your code.
- Always follow existing code patterns and module structure in your working directory.
- Be concise. Commit small, frequent changes for readable diffs.
- Proactively use web search if there is any uncertainty or lack of knowledge.

## Writing Code

- Prefer to write docstring and unit tests first (TDD approach).
- No 'any' type hints, use specific types.

## Python

- Always use `uv run` instead of `python` or `python3` when executing Python scripts or commands.
- If dependency errors occur, run `uv sync` first to install project dependencies.
- Examples:
  - Use `uv run script.py` instead of `python script.py`
  - Use `uv run -m pytest` instead of `python -m pytest`
  - Use `uv run -m pip install` instead of `pip install`

## Security

- Never commit secrets, credentials, or API keys.
- Use environment variables or secret management tools for sensitive data.
- Review dependency changes for known vulnerabilities before committing.

## Testing

- Write tests for new features before or alongside implementation.
- Run existing tests before committing when the project has a test suite (e.g., `uv run -m pytest`, `npm test`).
- For Nix-only projects, defer to project-specific build/test rules.
- Cover edge cases and error scenarios in tests.

## Code Review

- Focus on: readability, maintainability, security, and performance.
- Suggest improvements constructively with clear explanations.
- Check for edge cases and proper error handling.
- Verify that changes align with existing code patterns.

## Documentation

- Update README.md when adding new features or changing behavior.
- Add docstrings/comments for complex logic only when necessary.
- Keep documentation in sync with code changes.
- Do NOT create one-off or temporary documentation files.

## Error Handling

- Always handle errors gracefully; avoid silent failures.
- Use specific error types when possible.
- Log errors with enough context for debugging.
- Provide meaningful error messages to users.

## Custom Agents

Use the appropriate custom agent for specialized tasks:

- **@review**: Invoke when reviewing code for quality, best practices, potential bugs, or security issues. This agent provides constructive feedback without making direct changes.
- **@troubleshoot**: Invoke when analyzing error logs, stack traces, or debugging issues. This agent helps identify root causes and proposes solutions.

Example usage:

```text
@review Check this authentication implementation for security issues
@troubleshoot Analyze this error: [paste error log]
```

## Prompt Keywords

When the user's message contains any of these keywords (case-insensitive, typically
at the end of the message), apply the associated behavior throughout the entire task.
Strip the keyword from the message before processing the actual request.

| Keyword | Behavior                                                                                                                                                                                                                                                                                                                     |
| ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `webs`  | **Aggressive web search mode.** Before writing ANY code or making decisions, search the web first. Use web search to verify APIs, check latest docs, find best practices, and confirm syntax. When in doubt, search again. Prefer up-to-date web results over your training data. Search at minimum 3 times during the task. |

## Skills

Load these skills for specialized workflows. Skills provide step-by-step guidance for specific tasks.

- **/git-commit**: Load when creating git commits. Ensures conventional commit format and best practices.
- **/git-pr**: Load when creating GitHub pull requests. Provides structured PR descriptions.
