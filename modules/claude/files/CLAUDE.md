# CLAUDE.md

## Codex MCP 적극 위임 정책 (PROACTIVE)

> **CRITICAL**: 아래 세 가지 위임 규칙을 모든 작업에 적극적으로 적용한다.
> 해당 조건이 충족되면 사용자 요청 없이도 자발적으로 위임한다.

### 1. 분석 → `/codex:analyze`

이슈, 작업, 코드, 로그, 에러, 성능 등 **분석이 필요한 모든 경우**에 위임한다.

- 버그 원인 분석, 성능 병목 파악, 의존성 분석
- 프로젝트 구조/아키텍처 분석
- 로그/에러 패턴 분석
- 요구사항이 모호하여 사전 조사가 필요한 경우

```text
/codex:analyze "<분석 대상 설명>"
```

### 2. 구현 → `/codex:hephaestus`

**복잡한 구현 작업**을 Codex에 위임하여 자율적으로 수행한다.

- 3개 이상 파일 수정이 예상되는 구현
- 새로운 기능/모듈 추가, 대규모 리팩토링
- 여러 파일에 걸친 일괄 변경 (rename, migration)
- 위임하지 않는 경우: 1~2개 파일 단순 수정, 탐색만 필요한 작업, 사용자가 직접 구현을 요청한 경우

```text
/codex:hephaestus "<작업 목표 설명>"
```

### 3. 리뷰 → `/codex:critic`

Claude Code main agent가 수행한 **모든 의미 있는 작업**을 독립 검증한다.

- **필수 실행**: 구현 완료 직후 (커밋 전), 계획 수립 직후 (구현 착수 전)
- **대상**: 2개 이상 파일 수정, 새 기능 추가, 리팩토링, 동작 변경
- **verdict 후속**: fail → 수정 후 재검증, warn → 사용자에게 보고, pass → 커밋 진행
- `/codex:critic` 대신 다른 리뷰 스킬을 사용하지 말 것

```text
/codex:critic "<원래 사용자 요청 요약>"
```

---

## Verification & Inquiry Protocol (TOP PRIORITY)

> **CRITICAL**: Apply at EVERY step. This overrides all other instructions.

- **Verify before moving on.** Confirm each step succeeded with evidence (tests, diagnostics, diffs) — never assume.
- **Ask, don't guess.** If requirements are ambiguous or context is missing, ask the user immediately.
- **Surface blockers early.** Flag missing info, risky assumptions, or dependencies NOW — not after building on them.

## Worktree Workflow

By default, work on the current branch. Only use git worktree when the user explicitly requests it.
For large-scale changes (e.g., new features, major refactors), ask the user whether to use a worktree before proceeding.

**When worktree is requested:**

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

## Planning & Approval

For single-file, low-risk changes that can be explained in one short paragraph (for example, wording/description edits or small branch tweaks), do not route through plannotator for separate plan approval; apply directly, then verify with targeted evidence (diff and relevant check results). Use formal plan approval through plannotator only for multi-file, cross-module, or behavior-changing work.

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

## Codex MCP 위임 상세 워크플로우

> 위임 기준과 사용법은 최상단 "Codex MCP 적극 위임 정책" 참조.

### Hephaestus 워크플로우

1. 사용자 요청 분석 → 위임 기준 충족 여부 판단
2. 충족 시 사용자에게 "Codex에 위임합니다" 안내 후 `/codex:hephaestus` 실행
3. Codex 실행 완료 후 변경사항 독립 검증 (git diff 확인, 파일 리뷰)
4. `/codex:critic`으로 최종 리뷰
5. 결과를 사용자에게 보고

### Critic 규칙

- 사용자가 명시적으로 요청하지 않아도 실행 시점에 도달하면 자발적으로 호출할 것
- 리뷰 없이 커밋하지 말 것 (대상 작업인 경우)
- `/codex:critic` 대신 `/plannotator-review` 또는 다른 스킬을 사용하지 말 것

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

## Prompt Keywords

When the user's message contains any of these keywords (case-insensitive, typically
at the end of the message), apply the associated behavior throughout the entire task.
Strip the keyword from the message before processing the actual request.

| Keyword | Behavior                                                                                                                                                                                                                                                                                                                     |
| ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `webs`  | **Aggressive web search mode.** Before writing ANY code or making decisions, search the web first. Use web search to verify APIs, check latest docs, find best practices, and confirm syntax. When in doubt, search again. Prefer up-to-date web results over your training data. Search at minimum 3 times during the task. |

## Plan Submission

When you have completed your plan, you MUST call the `submit_plan` tool to submit it for user review.
The user will be able to:

- Review your plan visually in a dedicated UI
- Annotate specific sections with feedback
- Approve the plan to proceed with implementation
- Request changes with detailed feedback

If your plan is rejected, you will receive the user's annotated feedback. Revise your plan
based on their feedback and call submit_plan again.

Do NOT proceed with implementation until your plan is approved.
