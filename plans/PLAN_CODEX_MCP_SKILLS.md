# Plan: Codex 스킬을 `codex exec` → `codex mcp-server` MCP 방식으로 개편

## Context

현재 codex 플러그인의 세 스킬(critic, hephaestus, analyze)은 `codex exec` CLI를 Bash로 호출하여 동작함.
이를 `codex mcp-server`를 MCP 서버로 등록하고, MCP 도구(`codex`, `codex-reply`)를 직접 호출하는 방식으로 전환.

**장점**: 파일 기반 I/O 제거, shell 메타캐릭터 문제 해소, thread 기반 대화 연속성, 구조화된 응답.

## 사전 작업: 현재 analyze 스킬 커밋

현재 claude-marketplace에 미커밋 상태인 analyze 스킬 변경사항(6개 파일)을 먼저 커밋.
MCP 마이그레이션은 별도 커밋으로 진행.

## Phase 1: nix-flakes — MCP 서버 등록 (2개 파일)

### 1-1. `modules/claude/default.nix` 수정

`mcpCommands`를 structured format으로 리팩토링 (현재 index 기반 name extraction이 stdio 명령을 지원 불가):

```nix
# Before (string list, index-based name extraction)
mcpCommands = [
  "mcp add -s user --transport http context7 https://mcp.context7.com/mcp"
  "mcp add -s user --transport http notion https://mcp.notion.com/mcp"
];

# After (attrset list, explicit name)
mcpCommands = [
  { name = "context7"; cmd = "mcp add -s user --transport http context7 https://mcp.context7.com/mcp"; }
  { name = "notion"; cmd = "mcp add -s user --transport http notion https://mcp.notion.com/mcp"; }
  { name = "codex"; cmd = "mcp add -s user codex -- codex mcp-server"; }
];
```

Activation script의 name extraction 로직도 변경:

```nix
# Before
name = builtins.elemAt (lib.splitString " " cmd) 6;

# After
name = mp.name;
cmd = mp.cmd;
```

### 1-2. `modules/claude/files/settings.json` 수정

permissions.allow에 MCP 도구 및 analyze 스킬 추가:

```json
{
  "permissions": {
    "allow": [
      "mcp__codex__codex",
      "mcp__codex__codex-reply",
      "Skill(codex:analyze)"
    ]
  }
}
```

## Phase 2: claude-marketplace — 스킬 커맨드 재작성 (3개 파일 수정)

### 공통 변경 패턴 (critic, hephaestus, analyze 모두)

**제거:**

- `` ```! `` 초기화 블록 (CODEX_HOME 설정, AGENTS.md 복사, symlinks)
- Bash 기반 `codex exec` 호출
- `/tmp/{skill}-prompt.txt` 파일 기반 프롬프트 전달
- JSONL 스트리밍 (`tail -f`, `stream-progress.sh`, `kill`)
- `--output-last-message` 파일 기반 결과 읽기

**추가:**

- `mcp__codex__codex` 도구 호출 (초기 분석)
- `mcp__codex__codex-reply` 도구 호출 (반복 개선, threadId 기반)
- 에이전트 페르소나를 Read 도구로 `${CLAUDE_PLUGIN_ROOT}/agents/` 에서 읽어 프롬프트에 포함

**유지:**

- 입력 결정 cascade 로직 (explicit → git diff/project → context)
- 반복 개선 루프 (중단 조건, 최대 횟수)
- 결과 보고 형식
- 세션 파일 저장 (`~/.ai/{skill}-{SESSION_ID}-result.json`) — 감사 추적용

### 2-1. `commands/critic.md` 재작성

**frontmatter 변경:**

```yaml
allowed-tools:
  - Bash          # git diff 수집용
  - Read          # 파일 읽기, 에이전트 페르소나 읽기
  - Glob
  - Grep
  - mcp__codex__codex
  - mcp__codex__codex-reply
```

**실행 흐름:**

1. 전제 조건: `command -v codex` 확인 (유지)
2. 입력 결정: git diff / explicit content / context (유지)
3. 에이전트 페르소나: Read로 `${CLAUDE_PLUGIN_ROOT}/agents/codex-critic-agents.md` 읽기
4. 프롬프트 구성: 기존 템플릿 + 페르소나를 문자열로 조합
5. MCP 호출: `mcp__codex__codex(prompt=..., ...)` — threadId 수신
6. 반복: `mcp__codex__codex-reply(threadId=..., message=refinement_prompt)`
7. 결과 저장: Bash로 `~/.ai/critic-{SESSION_ID}-result.json`에 저장
8. 보고: 기존 형식 유지

### 2-2. `commands/hephaestus.md` 재작성

critic과 동일 패턴. 차이점:

- 컨텍스트 수집 단계 유지 (Glob/Grep/Read)
- `codex-reply` 사용 시 Codex가 이전 턴의 파일 상태를 기억하므로 refinement 프롬프트 단순화 가능
- 완료 후 독립 검증 단계 유지 (git diff 확인)

### 2-3. `commands/analyze.md` 재작성

critic과 동일 패턴. 차이점:

- sandbox: read-only (프롬프트에 명시)
- 입력 모드: explicit content / project structure / context

## Phase 3: 정리 및 문서 업데이트 (4개 파일)

### 3-1. `skills/codex/scripts/stream-progress.sh` 삭제

MCP 방식에서는 불필요.

### 3-2. `skills/codex/.claude-plugin/plugin.json` 수정

version을 `2.0.0`으로 범프 (breaking change: MCP 서버 필수).

### 3-3. `skills/codex/README.md` 수정

MCP 기반 아키텍처 설명으로 업데이트. Prerequisites에 codex MCP 서버 등록 추가.

### 3-4. `nix-flakes CLAUDE.md` 수정

Codex 스킬 섹션에 MCP 기반 동작 설명 및 `/codex:analyze` 추가.

## 파일 변경 요약

| Repository | File | Action |
|---|---|---|
| nix-flakes | `modules/claude/default.nix` | 수정 (mcpCommands 리팩토링 + codex 추가) |
| nix-flakes | `modules/claude/files/settings.json` | 수정 (MCP 도구 permission + analyze 스킬) |
| nix-flakes | `CLAUDE.md` | 수정 (analyze 스킬 문서 추가) |
| claude-marketplace | `skills/codex/commands/critic.md` | 재작성 |
| claude-marketplace | `skills/codex/commands/hephaestus.md` | 재작성 |
| claude-marketplace | `skills/codex/commands/analyze.md` | 재작성 |
| claude-marketplace | `skills/codex/scripts/stream-progress.sh` | 삭제 |
| claude-marketplace | `skills/codex/.claude-plugin/plugin.json` | 수정 (v2.0.0) |
| claude-marketplace | `skills/codex/README.md` | 수정 |

에이전트 페르소나(`agents/*.md`)와 출력 스키마(`references/*.json`)는 변경 없이 유지.

## 검증 방법

1. `home-manager build --flake .#devsisters-macbook` — nix 빌드 확인
2. `home-manager switch` 후 `claude mcp list` — codex 서버 등록 확인
3. `/codex:critic "test"` — MCP 도구 호출 성공 확인
4. `/codex:hephaestus "간단한 테스트 작업"` — thread 기반 실행 확인
5. `/codex:analyze "현재 프로젝트 분석"` — read-only 분석 확인
