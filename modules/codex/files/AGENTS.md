# AGENTS.md

## Verification & Inquiry Protocol (TOP PRIORITY)

> **CRITICAL**: Apply at every step. This overrides all other instructions.

- **Verify before moving on.** Confirm each step succeeded with evidence (diffs, checks, diagnostics) and never assume.
- **Ask, don't guess.** If requirements are ambiguous or context is missing, ask for clarification before proceeding.
- **Surface blockers early.** Flag missing information, risky assumptions, and dependency issues immediately.

## Git

> **CRITICAL**: After completing each self-contained, logical change, immediately
> commit it locally. Do NOT batch multiple unrelated changes.

- Make small, focused commits for each logical change.
- Write clear, descriptive commit messages.
- Prefer Conventional Commits (for example, `feat:`, `fix:`, `docs:`).
- Use imperative mood (for example, `Add feature`, not `Added feature`).
- Keep commits atomic and avoid mixing unrelated changes.
- Do not push unless explicitly requested.

## Planning & Approval

**Simple changes** (single-file, low-risk edits):

- Apply directly, then verify with diff and relevant check results.

**Complex changes** (multi-file, cross-module, or behavior-changing work):

- Present the plan to the user and request approval before implementing.
- If the user provides feedback, revise the plan accordingly.

## Critical Rules

- First, deeply understand and think about what you want to achieve with your code.
- Always follow existing code patterns and module structure in your working directory.
- Be concise. Commit small, frequent changes for readable diffs.
- Proactively use web search if there is any uncertainty or lack of knowledge.
- Always use `rg` (ripgrep) instead of `grep`. This applies to all contexts: shell commands, scripts, and Nix expressions.

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
- Run existing tests before committing when the project has a test suite (for example, `uv run -m pytest`, `npm test`).
- For Nix-only projects, defer to project-specific build/test rules.
- Cover edge cases and error scenarios in tests.

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

## Sandbox Awareness (Codex)

- Codex runs with `sandbox_mode = "danger-full-access"`.
- You have full filesystem and network access. Exercise caution with destructive operations.
- Do not use destructive commands unless explicitly approved.

## Exec Mode Guidelines (Codex)

- Assume non-interactive execution by default (for example, `codex exec ...`).
- Make steps reproducible and deterministic.
- Prefer explicit command flags and stable output formats.
- Validate each major step with command output, file diffs, or checks.

## Output Expectations (Codex)

- When `--output-schema` is provided, return strictly valid JSON that matches the schema.
- Do not add markdown or prose outside the required structured output.
- Keep fields complete, accurate, and machine-parseable.
