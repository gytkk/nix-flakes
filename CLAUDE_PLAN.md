# CLAUDE.md Opus 4.7 최적화 개선안

## Context

현재 `modules/claude/files/CLAUDE.md` (124줄)는 Opus 4.6 기준으로 작성되었다. Opus 4.7은 다음과 같은 행동 변화가 있어 프롬프트 조정이 필요하다:

- **공격적 강조 표현에 과잉 반응**: "CRITICAL", "TOP PRIORITY", "YOU MUST" 등에 overtrigger — 정상적 표현으로 대체 필요
- **자기 검증 능력 향상**: 별도 scaffolding 없이도 스스로 결과를 검증함 — 과도한 검증 지시 제거
- **더 literal한 instruction following**: 범위를 명시적으로 서술해야 함
- **도구 사용 빈도 감소**: 추론으로 대체하는 경향 — "if in doubt, use [tool]" 스타일 제거
- **legacy anti-laziness scaffolding 불필요**: "reason carefully", "Apply at EVERY step" 등 제거, effort level로 대체
- **Priority saturation 문제**: 모든 것이 CRITICAL이면 아무것도 CRITICAL하지 않음

## 수정 대상

- `modules/claude/files/CLAUDE.md` (1개 파일)

## 변경 사항

### 1. Priority saturation 해소

**현재**: 3개 섹션에 "TOP PRIORITY" / "CRITICAL" 사용 (Skill Discovery, Verification, Git Workflow)

**개선**: 진짜 중요한 규칙 1-2개만 강조, 나머지는 일반 표현으로 전환

| 섹션 | 현재 | 개선 |
|------|------|------|
| Skill Discovery | `> **CRITICAL**: Before starting work...` | 일반 bullet으로 전환 |
| Verification & Inquiry | `> **CRITICAL**: Apply at EVERY step. This overrides all other instructions.` | 제거 — Opus 4.7은 자체 검증함 |
| Git & Commit Workflow | `> **CRITICAL**: Follow the single flow...` | 일반 표현으로 전환 |

### 2. Verification & Inquiry Protocol 섹션 대폭 축소

**현재** (8줄):
```
> **CRITICAL**: Apply at EVERY step. This overrides all other instructions.
- **Verify before moving on.** Confirm each step succeeded with evidence...
- **Ask, don't guess.** If requirements are ambiguous...
- **Surface blockers early.** Flag missing info...
```

**개선**: Opus 4.7은 자체 검증 능력이 크게 향상됨. "Ask, don't guess"만 유지하고 나머지는 제거.

### 3. 자명한 섹션 제거/축소

다음 섹션들은 Claude가 이미 기본적으로 따르는 행동이므로 제거:

- **Error Handling** (전체 삭제): "Handle errors gracefully", "Use specific error types", "Log errors" — 모두 기본 행동
- **Code Review** (전체 삭제): "Focus on readability, maintainability, security, performance" — 기본 행동
- **Security** (축소): "Never commit secrets" 한 줄만 유지, 나머지 제거
- **Documentation** (축소): 프로젝트 CLAUDE.md에 이미 있는 규칙과 중복 제거
- **Testing** (축소): "Write tests for new features" — TDD 규칙과 중복

### 4. 긍정적 표현으로 전환

| 현재 (부정형) | 개선 (긍정형) |
|---|---|
| "Do not bundle unrelated changes" | "One logical change per commit" |
| "Do NOT push unless explicitly requested" | "Push only when explicitly requested" |
| "Do NOT create one-off or temporary documentation files" | 제거 (자명) |

### 5. 남길 핵심 규칙만 정리

최종 구조:

```
# CLAUDE.md

## Skill Discovery
(강조 없이, 3 bullet)

## Inquiry Protocol
(1 bullet: 모호하면 즉시 질문)

## Git & Commit Workflow
(현재 구조 유지, 강조 표현만 제거)

## Planning & Approval
(현재 유지)

## Worktree Workflow
(현재 유지)

## Looping Plugins
(현재 유지)

## Critical Rules
(현재 유지, "think step by step" 류 표현 없음 — 이미 깔끔)

## Writing Code
(현재 유지)

## Python
(현재 유지)
```

### 6. 삭제 대상 섹션

- ~~Verification & Inquiry Protocol~~ → "Inquiry Protocol"로 1줄 축소
- ~~Security~~ → Critical Rules에 1줄 병합
- ~~Testing~~ → Writing Code에 TDD 규칙으로 이미 포함
- ~~Code Review~~ → 전체 삭제
- ~~Documentation~~ → 전체 삭제
- ~~Error Handling~~ → 전체 삭제

### 예상 결과

- **현재**: 124줄, 6개 강조 표현, 3개 자명한 섹션
- **개선 후**: ~75줄, 0-1개 강조 표현, 핵심 규칙만 유지
- prompt cache 안정성 향상 (파일 크기 감소)
- Opus 4.7의 literal instruction following에 최적화

## Verification

- 변경 후 `nixfmt`으로 Nix 파일 포맷팅 필요 없음 (markdown 파일)
- markdownlint 규칙 준수 확인
- diff로 삭제/변경 내용 사용자 확인

