# CLAUDE.md

## Verification & Inquiry Protocol (TOP PRIORITY)

> **CRITICAL**: Apply at EVERY step. This overrides all other instructions.

- **Verify before moving on.** Confirm each step succeeded with evidence (tests, diagnostics, diffs) — never assume.
- **Ask, don't guess.** If requirements are ambiguous or context is missing, ask the user immediately.
- **Surface blockers early.** Flag missing info, risky assumptions, or dependencies NOW — not after building on them.

## Codex MCP Usage Policy

> Codex tools (`/codex:hephaestus`, `/codex:critic`, `/codex:analyze`, `/codex:debate`) are **only used when the user explicitly requests them**.
> Do NOT invoke Codex tools proactively or autonomously.

### Review with `/codex:critic`

When the user requests a review, or when changes are large-scale, use `/codex:critic` to independently verify work.

**Large-scale change criteria** (review when ALL apply):

- 5+ files modified
- New module/feature added or major architectural refactoring
- Public interface (API, export, option) changes

**Not subject to review**: Changes that do not meet all of the above criteria, unless the user explicitly requests a review.

**Verdict criteria**:

| Verdict | Criteria                                                                         | Follow-up Action            |
| ------- | -------------------------------------------------------------------------------- | --------------------------- |
| `fail`  | Functional error, unmet requirements, security vulnerability, build/test failure | Fix and re-verify           |
| `warn`  | Style inconsistency, minor edge case, improvement suggestion                     | Report to user for decision |
| `pass`  | Requirements met, follows existing patterns, no side effects                     | Proceed to commit           |

```text
/codex:critic "<summary of original user request>"
```

---

## Git & Commit Workflow

> **CRITICAL**: Follow the single flow from change completion through commit.

1. Complete one logical change
2. If large-scale change (see Codex MCP Usage Policy) → Run `/codex:critic`
   - `pass` → Proceed to commit
   - `warn` → Report to user; commit only after explicit approval
   - `fail` → Fix and re-verify
3. Otherwise → Commit immediately
4. Do not bundle unrelated changes into a single commit

**Commit rules**:

- [Conventional Commits](https://www.conventionalcommits.org/) format (e.g., `feat:`, `fix:`, `docs:`)
- Reference git commit history to maintain consistent message style
- Imperative mood (e.g., "Add feature" not "Added feature")
- Do NOT push unless explicitly requested

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

**When worktree is requested:**

1. Create a new branch and worktree: `git worktree add ~/worktrees/$(basename $PWD)/<short-task-name> -b <branch-name>`
2. Change to the worktree directory and work there
3. When done, create a PR from the worktree branch
4. After merge, clean up: `git worktree remove ~/worktrees/$(basename $PWD)/<short-task-name>`

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

## QMD (Local Knowledge Search)

- QMD MCP server is registered. Prefer QMD tools when searching markdown notes and documents.
- Use Grep/Glob for codebase file searches; use QMD for personal notes, documents, and knowledge searches.
- Indexed collections: `development`, `workspace`, `worktrees` (markdown files only)

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
