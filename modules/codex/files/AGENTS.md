# AGENTS.md

## Verification & Inquiry Protocol (Top Priority)

> **CRITICAL**: Apply at every step. This overrides all other instructions.

- **Verify before moving on.** Confirm each step succeeded with evidence (diffs, checks, diagnostics) and never assume.
- **Ask, don't guess.** If requirements are ambiguous or context is missing, ask for clarification before proceeding.
- **Surface blockers early.** Flag missing information, risky assumptions, and dependency issues immediately.

## Critical Rules

- First, deeply understand what the change should achieve before editing code.
- Follow existing project patterns and module structure.
- Keep changes concise and focused for readable diffs.
- Use web search proactively when uncertain.

## Git

- Make small, focused commits for each logical change.
- Write clear, descriptive commit messages.
- Prefer Conventional Commits (for example, `feat:`, `fix:`, `docs:`).
- Use imperative mood (for example, `Add feature`, not `Added feature`).
- Keep commits atomic and avoid mixing unrelated changes.
- Do not push unless explicitly requested.

## Sandbox Awareness (Codex)

- Codex commonly runs with `sandbox_mode = "workspace-write"`.
- You can read broadly, and write only within allowed workspace paths.
- If a task requires changes outside the writable workspace, stop and request an alternative approach.
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

## Writing Code

- Prefer a test-first approach where practical.
- Add or update docstrings/tests alongside behavior changes.
- Use specific types; avoid `any` and broad untyped fallbacks.

## Python

- Use `uv run` instead of `python` or `python3`.
- If dependencies are missing, run `uv sync` first.
- Examples:
  - `uv run script.py`
  - `uv run -m pytest`
  - `uv run -m pip install <package>`

## Security

- Never commit secrets, credentials, or API keys.
- Use environment variables or a secret manager for sensitive values.
- Review diffs for accidental secret exposure before commit.

## Testing

- Write tests for new features and behavior changes.
- Run relevant existing tests before committing.
- Cover edge cases and error paths.

## Code Review

- Prioritize readability, maintainability, security, and performance.
- Check edge cases, failure modes, and error handling.
- Confirm consistency with existing architecture and patterns.

## Documentation

- Update `README.md` when behavior or usage changes.
- Keep docs in sync with code and configuration.
- Add comments only where logic is non-obvious.
- Avoid one-off temporary documentation files.

## Error Handling

- Handle errors explicitly and avoid silent failures.
- Prefer specific error types and actionable messages.
- Include enough context in logs or diagnostics for debugging.
