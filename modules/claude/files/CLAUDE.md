# CLAUDE.md

## Verification & Inquiry Protocol (TOP PRIORITY)

> **CRITICAL**: Apply at EVERY step. This overrides all other instructions.

- **Verify before moving on.** Confirm each step succeeded with evidence (tests, diagnostics, diffs) — never assume.
- **Ask, don't guess.** If requirements are ambiguous or context is missing, ask the user immediately.
- **Surface blockers early.** Flag missing info, risky assumptions, or dependencies NOW — not after building on them.

## Codex MCP Delegation Policy (PROACTIVE)

> **CRITICAL**: Apply the two delegation rules below to all tasks proactively.
> When conditions are met, delegate autonomously without waiting for user request.

### 1. Implementation → `/codex:hephaestus`

Delegate **complex implementation tasks** to Codex for autonomous execution.

**Delegation criteria** (delegate when one or more apply):

- Implementation expected to modify 3+ files
- Adding new features/modules, large-scale refactoring
- Bulk changes across multiple files (rename, migration)
- Changes involving public interfaces (API, export, option)

**Do NOT delegate**: Simple 1–2 file edits, exploration-only tasks, or when the user explicitly requests direct implementation

> **Priority**: When delegation and non-delegation criteria overlap (e.g., single file but public interface change),
> delegation criteria take precedence.

```text
/codex:hephaestus "<description of task objective>"
```

### 2. Review → `/codex:critic`

Independently verify work performed by the Claude Code main agent.

**Review targets** (review when one or more apply):

- 2+ files modified
- New feature/module added
- Refactoring or existing behavior changes
- Public interface (API, export, option) changes

**Not subject to review**: Single-file typo/wording fixes, comment/docs-only changes, formatting-only changes

**Verdict criteria**:

| Verdict | Criteria                                                                         | Follow-up Action            |
| ------- | -------------------------------------------------------------------------------- | --------------------------- |
| `fail`  | Functional error, unmet requirements, security vulnerability, build/test failure | Fix and re-verify           |
| `warn`  | Style inconsistency, minor edge case, improvement suggestion                     | Report to user for decision |
| `pass`  | Requirements met, follows existing patterns, no side effects                     | Proceed to commit           |

```text
/codex:critic "<summary of original user request>"
```

### Codex Delegation Workflow

```text
User request → Evaluate delegation criteria
  ├─ Delegation target → User approval (Planning & Approval) → /codex:hephaestus → git diff verification → Review if applicable → /codex:critic → Commit
  └─ Direct implementation
      ├─ Complex change → User approval (Planning & Approval) → Implement → Review if applicable → /codex:critic → Commit
      └─ Simple change → Implement → Review if applicable → /codex:critic → Commit
```

- Invoke proactively when the execution point is reached, even without explicit user request
- Do NOT use `/plannotator-review` or other review skills in place of `/codex:critic`
- If Codex MCP tools are unavailable or unresponsive, fall back to direct execution by the main agent

---

## Git & Commit Workflow

> **CRITICAL**: Follow the single flow from change completion through commit.

1. Complete one logical change
2. If subject to review → Run `/codex:critic`
   - `pass` → Proceed to commit
   - `warn` → Report to user; commit only after explicit approval
   - `fail` → Fix and re-verify
3. If not subject to review → Commit immediately
4. Do not bundle unrelated changes into a single commit

**Commit rules**:

- [Conventional Commits](https://www.conventionalcommits.org/) format (e.g., `feat:`, `fix:`, `docs:`)
- Reference git commit history to maintain consistent message style
- Imperative mood (e.g., "Add feature" not "Added feature")
- Do NOT push unless explicitly requested

## Planning & Approval

> Complexity assessment uses the same criteria as the delegation policy (see Codex MCP Delegation Policy).

**Simple changes** (delegation criteria not met: 1–2 file simple edits, low risk):

- Apply immediately → Confirm with diff and verification results

**Complex changes** (delegation criteria met: 3+ files, new feature/module, public interface changes, etc.):

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

- QMD MCP 서버가 등록되어 있음. 텍스트 파일(문서, 코드, 설정 등) 검색 시 QMD 도구를 우선 활용할 것.
- 정확한 코드 매칭(특정 심볼, 정규식)에는 Grep/Glob 사용, 의미 기반 검색(유사 개념, 관련 파일 탐색)에는 QMD 사용.
- 인덱싱 대상 컬렉션: `development`, `workspace`, `worktrees`, `dotconfig`(~/.config)
- 인덱싱 대상 파일: 텍스트 파일 전체 (md, txt, nix, py, js, ts, go, rs, json, yaml, toml, tf 등)

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
