# Global agent rules

These rules apply across agent harnesses.
Harness-specific instructions may add tool usage details but should not duplicate or weaken these shared rules.
Project instructions closer to the working directory take precedence when they expressly override a global default.

## Skill discovery

- Before substantive work, check the available skills for a matching workflow.
- Use the best-fit skill when one exists and follow its instructions instead of improvising a duplicate workflow.
- If no skill fits, proceed without loading unrelated skills.

## Investigation and decisions

- Before changing files or asking questions, inspect applicable instructions and safely discoverable context: relevant code, tests, documentation, history, configuration, and useful read-only runtime state.
- Ask only about non-discoverable decisions that materially affect scope, rollout, disclosure, UX, ownership, or architecture.
- When genuine alternatives exist, offer two or three mutually exclusive, substantive choices with a recommendation.
  Otherwise, state the evidence-backed assumption and proceed.
- Do not present manufactured approval choices such as "Approve", "Revise", or "Reconsider" through a multiple-choice tool.
- Surface blockers, risky assumptions, and dependency issues early.

## Execution and planning

- Handle straightforward, low-risk changes directly.
- Present a short plan and obtain approval before implementation when work is high-risk, changes externally observable behavior, or crosses an explicit approval boundary in these or project-specific instructions.
- Keep plans verifiable and multi-step when needed.
  Reconcile each item as done, blocked, or cancelled before finishing.
- Avoid repeated reading or editing without progress.
  If blocked, stop with a concise diagnosis and a targeted question.
- Communicate at meaningful milestones or when blocked.
  Avoid noisy updates for routine tool calls.

## Scope discipline

- Make the smallest change that fully satisfies the request.
  Keep every change directly traceable to the requested outcome.
- Do not add unrelated features, refactors, abstractions, or compatibility layers.
  Follow existing project patterns and remove only code made obsolete by the requested change.
- If the implementation grows beyond what the problem requires, stop and simplify it.

## Git

- Unless the user asks otherwise, commit each completed and validated change using only files changed for the current task.
  Follow the repository's commit style, falling back to a small imperative Conventional Commit when none is established.
- Do not push unless the user explicitly requests it.

## Repository and tool use

- Use `rg` (ripgrep), never `grep`, including in shell commands, scripts, and Nix expressions.
- Decide which files and searches are needed before calling tools, and batch independent reads where practical.
- Set the working directory explicitly for shell commands and avoid `cd` unless necessary.
- Inspect each changed file or the final diff after editing.

## Editing safety

- Assume the worktree may already contain user changes.
- Ignore unrelated modified files.
  If a required file is already modified, understand and preserve those edits rather than overwriting them.
- Do not use destructive commands such as `git reset --hard` or `git checkout --` unless explicitly requested.

## Code, tests, and errors

- Prefer docstrings and unit tests before or alongside implementation.
- Use specific types rather than `any` type hints.
- Handle errors explicitly with meaningful messages and enough context for debugging.
  Avoid silent failures.
- Define observable success criteria for nontrivial changes.
  Reproduce a bug before demonstrating its fix, verify intended and failure behavior for a feature, and confirm behavior before and after a refactor.
- Run the narrowest relevant tests, linters, and formatters, then broaden checks according to scope and risk.
- Cover relevant edge cases and failure paths for new behavior.
- For Nix-only projects, follow the repository's Nix-specific validation rules.

## Code review

- Review for correctness, readability, maintainability, security, and material performance risks.
- Check relevant edge cases, error handling, and alignment with existing code patterns.
- Present findings constructively with specific evidence and clear remediation.

## Tool-specific workflows

- For Python, run commands through `uv run`, not `python`, `python3`, or bare `pip`.
  If dependencies are missing, inspect project instructions and dependency metadata before retrying.
  Prefer `uv sync --locked` when a lockfile exists.
  Obtain approval before synchronization that may update tracked files or declared dependencies.
  Examples: `uv run script.py`, `uv run -m pytest`, `uv run -m pip install`.
- For Notion, use the `ntn` CLI (`ntn pages`, `ntn datasources`, `ntn api`, and related commands).
  Do not use, add, or depend on a Notion MCP server.
- For Datadog, use the `pup` CLI.
  Start queries with narrow time ranges and small limits, and specify `--from` for time-series queries.
  When writing a script, runbook, or command that a user or CI will run outside the agent session, pass `--no-agent` so `pup` returns the same unwrapped output they will receive.
- These tool preferences do not authorize operations with external side effects.
  The approval requirements in the operating invariants still apply.

## Security

- Never commit secrets, credentials, API keys, or generated authentication material.
- Use environment variables or secret-management tools for sensitive data.
- Review dependency changes for known vulnerabilities before committing.
- Remember that agent tools may run with the current user's filesystem and network permissions even when a harness also provides a sandbox.

## Documentation

- Update README documentation when behavior or user-facing features change.
- Add comments or docstrings only when they clarify logic that the code does not make obvious.
- Keep maintained documentation synchronized with implementation.
- Do not create one-off or temporary documentation files.

## Completion

Before finishing:

- Include the local commit hash when a commit was created.
