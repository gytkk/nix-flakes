# CLAUDE.md

## Verification & Inquiry Protocol (TOP PRIORITY)

> **CRITICAL**: Apply at EVERY step. This overrides all other instructions.

- **Verify before moving on.** Confirm each step succeeded with evidence (tests, diagnostics, diffs) — never assume.
- **Ask, don't guess.** If requirements are ambiguous or context is missing, ask the user immediately.
- **Surface blockers early.** Flag missing info, risky assumptions, or dependencies NOW — not after building on them.

## Codex MCP 위임 정책 (PROACTIVE)

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

**위임 기준** (하나 이상 해당 시):

- 3개 이상 파일 수정이 예상되는 구현
- 새로운 기능/모듈 추가, 대규모 리팩토링
- 여러 파일에 걸친 일괄 변경 (rename, migration)
- 공개 인터페이스(API, export, option) 변경을 수반하는 작업

**위임하지 않는 경우**: 1~2개 파일 단순 수정, 탐색만 필요한 작업, 사용자가 직접 구현을 요청한 경우

> **우선순위**: 위임 기준과 비위임 기준이 겹치는 경우 (예: 1개 파일이지만 공개 인터페이스 변경),
> 위임 기준이 우선한다.

```text
/codex:hephaestus "<작업 목표 설명>"
```

### 3. 리뷰 → `/codex:critic`

Claude Code main agent가 수행한 작업을 독립 검증한다.

**리뷰 대상** (하나 이상 해당 시):

- 2개 이상 파일 수정
- 새 기능/모듈 추가
- 리팩토링 또는 기존 동작 변경
- 공개 인터페이스(API, export, option) 변경

**리뷰 비대상**: 단일 파일 내 오타/문구 수정, 주석/문서만 변경, 포맷팅만 변경

**verdict 판정 기준**:

| Verdict | 기준 | 후속 조치 |
| ------- | ---- | --------- |
| `fail` | 기능 오류, 요구사항 미충족, 보안 취약점, 빌드/테스트 실패 | 수정 후 재검증 |
| `warn` | 스타일 불일치, 미미한 엣지케이스, 개선 권장 사항 | 사용자에게 보고 후 판단 |
| `pass` | 요구사항 충족, 기존 패턴 준수, 부작용 없음 | 커밋 진행 |

```text
/codex:critic "<원래 사용자 요청 요약>"
```

### Codex 위임 워크플로우

```text
사용자 요청 → 위임 기준 판단
  ├─ 분석 필요 → /codex:analyze → 결과 보고
  ├─ 구현 위임 대상 → 사용자에게 안내 → /codex:hephaestus → git diff 검증 → /codex:critic → 커밋
  └─ 직접 구현 → 구현 완료 → 리뷰 대상이면 /codex:critic → 커밋
```

- 사용자가 명시적으로 요청하지 않아도 실행 시점에 도달하면 자발적으로 호출할 것
- `/codex:critic` 대신 `/plannotator-review` 또는 다른 리뷰 스킬을 사용하지 말 것

---

## Git & Commit Workflow

> **CRITICAL**: 변경 완료 후 커밋까지의 단일 흐름을 따른다.

1. 하나의 논리적 변경을 완료한다
2. 리뷰 대상이면 → `/codex:critic` 실행
   - `pass` → 커밋 진행
   - `warn` → 사용자에게 보고 후 명시적 승인을 받으면 커밋
   - `fail` → 수정 후 재검증
3. 리뷰 비대상이면 → 즉시 커밋
4. 여러 무관한 변경을 하나의 커밋에 묶지 않는다

**커밋 규칙**:

- [Conventional Commits](https://www.conventionalcommits.org/) 형식 (e.g., `feat:`, `fix:`, `docs:`)
- git commit history를 참고하여 일관된 메시지 스타일 유지
- 명령형 어조 (e.g., "Add feature" not "Added feature")
- Do NOT push unless explicitly requested

## Planning & Approval

**간단한 변경** (단일 파일, 저위험, 한 문단으로 설명 가능):

- plannotator 없이 즉시 적용 → diff와 검증 결과로 확인

**복잡한 변경** (다중 파일, 크로스 모듈, 동작 변경):

- `submit_plan` 도구로 계획을 제출하여 사용자 승인을 받은 후 구현
- 사용자가 피드백을 주면 계획을 수정하고 재제출
- `submit_plan` 도구가 사용 불가능한 경우: 계획을 텍스트로 사용자에게 제시하고 승인을 요청

## Worktree Workflow

By default, work on the current branch. Only use git worktree when the user explicitly requests it.
For large-scale changes (e.g., new features, major refactors), ask the user whether to use a worktree before proceeding.

**When worktree is requested:**

1. Create a new branch and worktree: `git worktree add ~/trees/$(basename $PWD)/<short-task-name> -b <branch-name>`
2. Change to the worktree directory and work there
3. When done, create a PR from the worktree branch
4. After merge, clean up: `git worktree remove ~/trees/$(basename $PWD)/<short-task-name>`

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
- Review dependency changes for known vulnerabilities before committing.

## Testing

- Write tests for new features before or alongside implementation.
- Run existing tests before committing (e.g., `uv run -m pytest`, `npm test`).
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

## Prompt Keywords

When the user's message contains any of these keywords (case-insensitive, typically
at the end of the message), apply the associated behavior throughout the entire task.
Strip the keyword from the message before processing the actual request.

| Keyword | Behavior |
| ------- | -------- |
| `webs` | **Aggressive web search mode.** Before writing ANY code or making decisions, search the web first. Use web search to verify APIs, check latest docs, find best practices, and confirm syntax. Search at minimum 3 times, maximum 10 times per task. Stop searching when two independent sources confirm the same answer or when results start repeating. Prefer up-to-date web results over training data. |
