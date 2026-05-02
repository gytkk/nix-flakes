# AGENTS.md

## Skill Discovery (TOP PRIORITY)

> **CRITICAL**: Before starting work on any request, first check whether an
> available skill fits the current request's context or situation.

- **Explore skills first.** Look for built-in, installed, admin, or
  repo-provided skills that match the user's request before improvising your
  own workflow.
- **Use the best-fit skill when appropriate.** If a relevant skill exists, use
  it and follow its workflow instead of bypassing it.
- **Only skip skills deliberately.** If no skill fits, or a skill is clearly
  not appropriate, proceed normally and state that choice when it matters.

## Verification & Inquiry Protocol (TOP PRIORITY)

> **CRITICAL**: Apply at every step. This overrides all other instructions.

- **Verify before moving on.** Confirm each step succeeded with evidence
  (diffs, checks, diagnostics) and never assume.
- **Ask when truly blocked.** Ask before destructive, security-sensitive,
  public API, data migration, dependency, or broad architecture changes.
- **State low-risk assumptions.** For reversible choices, state the assumption
  and proceed instead of ending with a clarification question.
- **Surface blockers early.** Flag missing information, risky assumptions, and
  dependency issues immediately.

## Autonomy & Operating Loop

- Default to delivering a working, verified change, not just a plan, unless the
  user explicitly asks for analysis only.
- Gather relevant context first, identify the smallest safe change, implement
  it, verify it, and report the outcome.
- Persist until the requested outcome is handled end to end, or until a
  concrete blocker prevents further safe progress.
- Avoid repeated rereading or re-editing without progress; if blocked, stop
  with a concise blocker and a targeted question.
- Communicate progress at meaningful milestones or when blocked; avoid noisy
  status updates for routine tool calls.

## Git

> **CRITICAL**: After completing each self-contained, logical change, immediately
> commit it locally. Do NOT batch multiple unrelated changes.

- Make small, focused commits for each logical change.
- Only stage and commit changes you made for the current task.
- Write clear, descriptive commit messages.
- Prefer Conventional Commits (for example, `feat:`, `fix:`, `docs:`).
- Use imperative mood (for example, `Add feature`, not `Added feature`).
- Keep commits atomic and avoid mixing unrelated changes.
- Do not commit when the user asked only for analysis, when checks fail without
  an explicit decision to preserve the failure, or when the user says not to
  commit.
- Do not push unless explicitly requested.

## Planning & Approval

**Simple changes** (single-file, low-risk edits):

- Apply directly, then verify with diff and relevant check results.

**Complex changes** (multi-file, cross-module, or behavior-changing work):

- Present the plan to the user and request approval before implementing.
- If the user provides feedback, revise the plan accordingly.

**Plan hygiene**:

- Use a short plan or checklist for nontrivial work; skip plans for
  straightforward tasks.
- Do not create single-step plans.
- Update the plan as steps complete.
- Before finishing, reconcile every plan item as done, blocked, or cancelled.
- Unless the user asks only for a plan, never end with a plan as the sole
  deliverable.

## Critical Rules

- First, deeply understand and think about what you want to achieve with your code.
- Always follow existing code patterns and module structure in your working directory.
- Be concise. Commit small, frequent changes for readable diffs.
- Proactively use web search if there is any uncertainty or lack of knowledge.
- Always use `rg` (ripgrep) instead of `grep`. This applies to all contexts:
  shell commands, scripts, and Nix expressions.

## Exploration & Tool Use

- Decide which files, searches, and resources are needed before calling tools.
- Batch independent reads and searches where possible, especially `rg`, `sed`,
  `ls`, `git show`, `nl`, and `wc`.
- Use sequential reads only when the next file cannot be known until seeing
  prior output.
- Use `apply_patch` for manual file edits. Formatting commands and generated
  outputs do not need `apply_patch`.
- Always set the working directory for shell commands. Avoid `cd` unless
  necessary.
- After editing, inspect the changed file or `git diff` before moving on.

## Writing Code

- Prefer to write docstring and unit tests first (TDD approach).
- No 'any' type hints, use specific types.

## Editing Safety

- You may be in a dirty git worktree.
- Never revert existing changes you did not make unless explicitly requested.
- If unrelated files contain user changes, ignore them.
- If a file you need already has changes you did not make, read it carefully
  and work with those changes instead of overwriting them.
- Do not use destructive commands such as `git reset --hard` or
  `git checkout --` unless explicitly requested.

## Python

- Always use `uv run` instead of `python` or `python3` when executing Python
  scripts or commands.
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
- Run existing tests before committing when the project has a test suite (for
  example, `uv run -m pytest`, `npm test`).
- For Nix-only projects, defer to project-specific build/test rules.
- Cover edge cases and error scenarios in tests.

## Definition of Done

- The diff contains only intentional changes for the current task.
- Relevant tests, linters, formatters, or project-specific checks have run, or
  skipped checks are explicitly explained.
- Documentation is updated when behavior changes.
- The final response includes changed files, verification results, commit hash
  when committed, and remaining risks.

## Documentation

- Update README.md when adding new features or changing behavior.
- Add docstrings/comments for complex logic only when necessary.
- Keep documentation in sync with code changes.
- Do NOT create one-off or temporary documentation files.

## Codex Skills

- When creating or updating Codex skills for this setup, use Codex's built-in
  `$skill-creator` first.
- Store repo-managed admin skills under `modules/codex/skills/` so they are
  exposed at `/etc/codex/skills`.
- Treat `$skill-creator` output as a scaffold: trim unused files, keep the
  skill focused, and align it with this repository's conventions before
  committing.

## Error Handling

- Always handle errors gracefully; avoid silent failures.
- Use specific error types when possible.
- Log errors with enough context for debugging.
- Provide meaningful error messages to users.

## Sandbox Awareness (Codex)

- Codex runs with `sandbox_mode = "danger-full-access"`.
- You have full filesystem and network access. Exercise caution with
  destructive operations.
- Do not use destructive commands unless explicitly approved.

## Exec Mode Guidelines (Codex)

- Assume non-interactive execution by default (for example,
  `codex exec ...`).
- Make steps reproducible and deterministic.
- Prefer explicit command flags and stable output formats.
- Validate each major step with command output, file diffs, or checks.

## Output Expectations (Codex)

- When `--output-schema` is provided, return strictly valid JSON that matches
  the schema.
- Do not add markdown or prose outside the required structured output.
- Keep fields complete, accurate, and machine-parseable.
