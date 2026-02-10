# Claude Code 에이전트 오케스트레이션 시스템

oh-my-opencode의 Sisyphus 패턴을 기반으로 한 Claude Code용 에이전트 오케스트레이션 시스템.

## 커밋 내역

`main` 브랜치에 2개의 커밋으로 구성:

1. `feat: add Sisyphus-style agent orchestration system for Claude Code`
2. `fix: improve orchestration prompts and fix librarian tool config`

## 생성된 파일: 커스텀 서브에이전트 6개 (`modules/claude/agents/`)

| 에이전트 | 모델 | 모드 | 역할 |
|-----------|------|------|------|
| **oracle** | opus | 읽기 전용 + 메모리 | 전략 자문 — 아키텍처, 디버깅, 성능 분석 |
| **explorer** | haiku | 읽기 전용 | 빠른 코드베이스 검색, 호출 체인 추적, 구조 탐색 |
| **librarian** | sonnet | 읽기 전용 + Context7 MCP | 외부 문서, 라이브러리 API, GitHub 리서치 |
| **planner** | opus | 읽기 전용 | 요구사항 분석, 리스크 평가, 구현 계획 수립 |
| **reviewer** | opus | 읽기 전용 + 메모리 | 코드 품질, 보안, 패턴 준수, 변경 후 검증 |
| **implementer** | opus | acceptEdits, maxTurns=100 | 자율적 코드 변경, 3회 시도 실패 프로토콜 포함 |

## 변경된 파일: `CLAUDE.md` (118줄 → 275줄)

기존 보일러플레이트(Python `uv run`, TDD 기본, 일반적인 보안/테스트 가이드라인)를 제거하고
다음 내용을 추가:

### Phase 0 — 의도 분류

5가지 요청 유형(Trivial, Explicit, Exploratory, Open-ended, Ambiguous)에 따른 액션 분류 및
위임 트리거 규칙.

### Phase 1 — 서브에이전트 레퍼런스

- 에이전트 테이블 (모델, 모드, 용도 일목요연)
- **6섹션 위임 프롬프트 구조**: TASK, EXPECTED OUTCOME, MUST DO, MUST NOT DO, CONTEXT, BACKGROUND
- 실행 패턴: 포그라운드/백그라운드/체이닝/리줌
- **전체 위임 예시**: Rate limiting 기능 추가 워크스루 (explore → plan → implement → review 체인)

### Phase 2 — 코드베이스 평가

Disciplined / Transitional / Legacy / Greenfield 4단계 분류 체계.

### Phase 3 — 검증 프로토콜

- 완료 게이트: 분류 → 실행 → 증거 → 요약의 순차 충족 필수
- 증거 요구사항 테이블 (파일 편집, 빌드, 테스트, 위임 각각의 증거)
- 위임 후 검증 체크리스트 4항목
- 에스컬레이션 규칙: 병렬 탐색기 3개 제한, 2회 실패 시 oracle 자문

### Phase 4 — 실패 복구

3회 시도 프로토콜: 분석 → 다른 접근법 → 중단 후 oracle 자문.
하드 규칙: 근본 원인 해결, 무작위 디버깅 금지, 테스트 삭제 금지.

### 그 외

- **태스크 관리**: 3단계 이상 작업 시 TodoWrite 필수
- **워크플로 규약**: Worktree + Git 컨벤셔널 커밋 (기존 유지)
- **커뮤니케이션 스타일**: 간결하게, 아첨 금지, 사용자 스타일에 맞춤 (Sisyphus 패턴)

## 변경된 파일: `default.nix`

1줄 추가: `home.file.".claude/agents".source = ./agents;`
— 모든 에이전트 파일을 `~/.claude/agents/`에 배포.

## Oracle 검증 후 적용된 수정 사항

- librarian에서 `WebSearch` 제거 (Claude Code 네이티브 도구가 아님 — WebFetch + `gh` CLI로 대체)
- 전체 위임 예시 추가 (explore → plan → implement → review 체인 시연)
- 완료 게이트 및 에스컬레이션 규칙을 검증 프로토콜에 추가

## 기존 에이전트와의 공존

마켓플레이스 에이전트(`@code-reviewer`, `@software-dev-engineer`, `@test-code-writer`)는
새 서브에이전트와 함께 유지됨. 별도 제거 없이 공존.
