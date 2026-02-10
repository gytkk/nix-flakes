# CLAUDE.md

## Teams (IMPORTANT)

- Prefer to work in teams when possible.
- Communicate effectively with team members.
- Collaborate on tasks and share knowledge.

## Verification & Inquiry Protocol (TOP PRIORITY)

> **CRITICAL**: Apply at EVERY step. This overrides all other instructions.

- **Verify before moving on.** Confirm each step succeeded with evidence (tests, diagnostics, diffs) — never assume.
- **Ask, don't guess.** If requirements are ambiguous or context is missing, ask the user immediately.
- **Surface blockers early.** Flag missing info, risky assumptions, or dependencies NOW — not after building on them.

## Worktree Workflow (RECOMMENDED)

> Before starting new task which adds new functionality or changes existing code, you will create a git worktree.
> Do NOT work directly on the main branch if you are not sure about the changes.

1. Create a new branch and worktree: `git worktree add ~/trees/$(basename $PWD)/<short-task-name> -b <branch-name>`
2. Change to the worktree directory and work there
3. When done, create a PR from the worktree branch
4. After merge, clean up: `git worktree remove ~/trees/$(basename $PWD)/<short-task-name>`

## Git

> **CRITICAL**: After completing each self-contained, logical change, immediately
> commit it locally. Do NOT batch multiple unrelated changes.

- Commit often with small, focused changes.
- Write clear, descriptive commit messages.
- Prefer [Conventional Commits](https://www.conventionalcommits.org/) format (e.g., `feat:`, `fix:`, `docs:`).
- Also check git commit history for examples of good commit messages.
- Write commit messages in imperative mood (e.g., "Add feature" not "Added feature").
- Keep commits atomic: one logical change per commit.
- Do NOT push unless explicitly requested.

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

## Testing

- Write tests for new features before or alongside implementation.
- Run existing tests before committing (e.g., `uv run -m pytest`, `npm test`).
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

- **@code-reviewer**: Invoke when reviewing code for quality, best practices, potential bugs, or security issues. This agent provides constructive feedback without making direct changes.
- **@software-dev-engineer**: Invoke when tackling complex problem-solving, system design decisions, performance optimization, or architectural recommendations.
- **@test-code-writer**: Invoke when writing comprehensive test suites based on implementation plans, specifications, or existing code.

Example usage:

```text
@code-reviewer Check this authentication implementation for security issues
@software-dev-engineer Design a scalable approach for this multi-API integration
@test-code-writer Write tests for this JWT authentication service
```

## Prompt Keywords

When the user's message contains any of these keywords (case-insensitive, typically
at the end of the message), apply the associated behavior throughout the entire task.
Strip the keyword from the message before processing the actual request.

| Keyword | Behavior                                                                                                                                                                                                                                                                                                                     |
| ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `webs`  | **Aggressive web search mode.** Before writing ANY code or making decisions, search the web first. Use web search to verify APIs, check latest docs, find best practices, and confirm syntax. When in doubt, search again. Prefer up-to-date web results over your training data. Search at minimum 3 times during the task. |
