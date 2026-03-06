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

- Always use `rg` (ripgrep) instead of `grep`. This applies to all contexts: shell commands, scripts, and Nix expressions.

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
