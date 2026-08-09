# AGENTS.md

## Skill Routing (TOP PRIORITY)

- Before substantive work, check the available skills for a matching workflow.
- For every request that writes, reviews, or refactors code, read and apply the
  `karpathy-guidelines` skill before proceeding.
- Read other specialized skills when their workflow clearly matches the task;
  use the best-fit skill instead of improvising a duplicate workflow.
- If no specialized skill fits, proceed without loading unrelated skills.

## Investigation and Decisions

- Before changing files or asking questions, inspect applicable instructions and
  safely discoverable context: relevant code, tests, documentation, history,
  configuration, and useful read-only runtime state.
- Ask only about non-discoverable decisions that materially affect scope,
  rollout, disclosure, UX, ownership, or architecture.
- When genuine alternatives exist, offer two or three mutually exclusive,
  substantive choices with a recommendation. Otherwise, state the
  evidence-backed assumption and proceed.
- Do not present manufactured approval choices such as “Approve,” “Revise,” or
  “Reconsider” through a multiple-choice tool.
- Surface blockers, risky assumptions, and dependency issues early.

## Execution and Planning

- Handle straightforward, low-risk changes directly.
- For multi-file, cross-module, high-risk, or behavior-changing work, present a
  short plan and obtain approval before implementation.
- Keep plans verifiable and multi-step when needed. Update them as work
  progresses and reconcile each item as done, blocked, or cancelled.
- Avoid repeated reading or editing without progress. If blocked, stop with a
  concise diagnosis and a targeted question.
- Communicate at meaningful milestones or when blocked; avoid noisy updates for
  routine tool calls.

## Git

- After each self-contained logical change, commit it locally immediately.
- Stage only changes made for the current task.
- Prefer small Conventional Commits in imperative mood.
- Do not commit analysis-only work, failed checks without an explicit decision
  to preserve the failure, or changes the user asked not to commit.
- Do not push unless explicitly requested.

## Repository and Tool Use

- Use web search when local evidence is insufficient or current external
  behavior matters.
- Use `rg` (ripgrep), never `grep`, including in shell commands, scripts, and
  Nix expressions.
- Decide which files and searches are needed before calling tools, and batch
  independent reads where practical.
- Use `read` to inspect files and `edit` for precise manual changes. Formatting
  commands and generated outputs do not require `edit`.
- Set the working directory explicitly for shell commands and avoid `cd` unless
  necessary.
- Inspect each changed file or `git diff` after editing.

## Editing Safety

- Assume the worktree may already contain user changes.
- Ignore unrelated modified files. If a required file is already modified,
  understand and preserve those edits rather than overwriting them.
- Never revert changes you did not make.
- Do not use destructive commands such as `git reset --hard` or
  `git checkout --` unless explicitly requested.

## Code, Tests, and Errors

- Prefer docstrings and unit tests before or alongside implementation.
- Use specific types rather than `any` type hints.
- Handle errors explicitly with meaningful messages and enough context for
  debugging; avoid silent failures.
- Run the narrowest relevant tests, linters, and formatters, then broaden checks
  according to scope and risk.
- Cover relevant edge cases and failure paths for new behavior.
- For Nix-only projects, follow the repository's Nix-specific validation rules.

## Python

- Run Python commands through `uv run`, not `python`, `python3`, or bare `pip`.
- If dependencies are missing, run `uv sync` before retrying.
- Examples: `uv run script.py`, `uv run -m pytest`, `uv run -m pip install`.

## Security

- Never commit secrets, credentials, API keys, or generated authentication
  material.
- Use environment variables or secret-management tools for sensitive data.
- Review dependency changes for known vulnerabilities before committing.
- Pi is not sandboxed by default; tools, extensions, and commands run with the
  current user's filesystem and network permissions.

## Notion

- Use the `ntn` CLI for Notion actions (`ntn pages`, `ntn datasources`,
  `ntn api`, and related commands).
- Do not use, add, or depend on a Notion MCP server.

## Documentation

- Update README documentation when behavior or user-facing features change.
- Add comments or docstrings only when they clarify non-obvious logic.
- Keep maintained documentation synchronized with implementation.
- Do not create one-off or temporary documentation files.

## Pi Skills

- Follow Pi's Agent Skills format: a focused `SKILL.md` with valid `name` and
  `description` frontmatter.
- Store repository-managed Pi skills under `modules/pi/skills/` so Home Manager
  exposes them at `~/.pi/agent/skills/`.
- Keep skills focused, trim unused files, and align them with repository
  conventions.
- Use `parallel-research-merge` for bounded multi-axis investigation when the
  task benefits from independent research scopes.
- Use parallel workers only when the session exposes an executable worker or
  subagent tool; otherwise, run the same scopes sequentially.

## Completion

Before finishing:

- Confirm the diff contains only intentional changes for the current task.
- Record relevant checks and explain any skipped or unavailable verification.
- Include the local commit hash when a commit was created.
