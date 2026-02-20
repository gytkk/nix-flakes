# CLAUDE.md

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

## Codex Critic 리뷰 (MANDATORY)

> **CRITICAL**: 이 섹션은 모든 의미 있는 작업에 대해 반드시 준수해야 한다.
> `/codex-critic` 스킬을 Skill 도구로 호출해야 한다. `plannotator-review` 등
> 다른 스킬로 대체하거나 건너뛰는 것은 허용되지 않는다.

계획 수립 또는 구현 작업을 완료한 후에는 **반드시** `/codex-critic` 스킬을 실행하여
독립적인 리뷰와 피드백을 받아야 한다. 코드 변경사항(diff)뿐만 아니라 계획, 설계 문서,
또는 임의의 콘텐츠도 검증할 수 있다.

### 필수 실행 시점

1. **계획 완료 후**: 구현 계획을 수립한 직후, 구현에 착수하기 전
2. **구현 완료 후**: 코드 변경을 마친 직후, 커밋 직전

### 대상

- 단순 오타 수정이나 1줄 변경이 아닌 **모든 의미 있는 작업**
- 2개 이상 파일 수정, 새 기능 추가, 리팩토링, 동작 변경 등

### 사용법

```text
/codex-critic "<원래 사용자 요청 요약>"
```

입력은 자동 감지된다: git diff가 있으면 diff 모드, 명시적 콘텐츠가 있으면 임의 입력 모드.

### 후속 조치

- `verdict: fail` → 이슈를 반영하여 수정 후 재검증
- `verdict: warn` → 사용자에게 이슈를 보고하고 판단을 요청
- `verdict: pass` → 커밋 진행

### 금지 사항

- `/codex-critic` 대신 `/plannotator-review` 또는 다른 스킬을 사용하지 말 것
- 리뷰 없이 커밋하지 말 것 (대상 작업인 경우)
- 사용자가 명시적으로 요청하지 않아도 위 실행 시점에 도달하면 스스로 호출할 것

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
