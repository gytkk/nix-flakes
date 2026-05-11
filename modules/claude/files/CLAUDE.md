# CLAUDE.md

## Skill Discovery

- Explore available skills first — look for built-in, installed, or repo-provided skills that match the user's request before improvising.
- Use the best-fit skill when one exists, and follow its workflow.
- If no skill fits, proceed normally and state that choice when it matters.

## Inquiry Protocol

- If requirements are ambiguous or context is missing, ask the user immediately instead of guessing.

## Git & Commit Workflow

1. Complete one logical change
2. If subject to review → Use `@review` agent
   - No issues → Proceed to commit
   - Issues found → Fix and re-verify
3. Otherwise → Commit immediately
4. One logical change per commit

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
- Push only when explicitly requested

## Planning & Approval

**Simple changes** (1–2 file simple edits, low risk):

- Apply immediately → Confirm with diff and verification results

**Complex changes** (3+ files, new feature/module, public interface changes, etc.):

- Use `EnterPlanMode` to design the approach, then `ExitPlanMode` to submit for user approval
- If the user provides feedback, revise the plan accordingly
- If plan mode tools are unavailable: Present the plan as text and request user approval

## Worktree Workflow

By default, work on the current branch. Only use git worktree when the user explicitly requests it.
Individual projects may override this policy (e.g., banning worktree entirely). Project-level CLAUDE.md rules take precedence.

**Worktree agent permissions:** Prefer the normal permission flow or `acceptEdits` in repo-local worktrees. Only use `bypassPermissions` in genuinely isolated environments such as containers or VMs.

## Looping Plugins

- When using Ralph Loop or any self-repeating plugin, always set a bounded stop condition such as `--max-iterations`, an explicit `--completion-promise`, or both.
- Do not start an unbounded loop with no exit condition. If a loop becomes stuck, stop and clear the loop state instead of asking the user to keep fighting the hook.

## Critical Rules

- First, deeply understand and think about what you want to achieve with your code.
- Always follow existing code patterns and module structure in your working directory.
- Be concise. Commit small, frequent changes for readable diffs.
- Proactively use web search if there is any uncertainty or lack of knowledge.
- Always use `rg` (ripgrep) instead of `grep`. This applies to all contexts: shell commands, scripts, and Nix expressions.
- Never commit secrets, credentials, or API keys.

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
