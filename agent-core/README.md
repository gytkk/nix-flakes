# Agent core 통합 계획

## 목적

`agent-core`를 `nix-flakes` 저장소의 최상위 `agent-core/`에서 관리한다. Python package가 공통 규칙과 skill을 런타임별 파일 트리로 materialize하고, `modules/openclaw`, `modules/codex`, `modules/claude`, `modules/pi`는 생성 결과를 설치하는 adapter 역할만 맡는다.

이 계획은 구현 범위와 의존성 방향을 정리한다. 현재 설정이나 runtime 파일은 변경하지 않는다.

## 목표 상태

```text
nix-flakes/
├── agent-core/
│   ├── pyproject.toml
│   ├── uv.lock
│   ├── manifest.toml
│   ├── src/agent_core/
│   ├── rules/
│   ├── skills/
│   ├── adapters/
│   ├── schema/
│   ├── nix/
│   └── tests/
├── modules/
│   ├── openclaw/
│   ├── codex/
│   ├── claude/
│   └── pi/
└── flake.nix
```

`agent-core/`는 Home Manager module이 아니다. Nix 없이도 실행하고 테스트할 수 있는 독립 Python package다. `modules/` 아래의 각 runtime module이 이 package의 출력에 의존한다.

## 소유권

### `agent-core/`

다음을 소유한다.

- 모든 coding agent가 공유하는 운영 규칙
- 공통 prose 규칙과 memory 접근 계약
- portable Agent Skills
- runtime별 instruction adapter
- skill 선택과 충돌 처리 규칙
- deterministic materialization
- 생성 결과 검증과 drift 검사
- manifest와 schema
- Python 단위 테스트와 통합 테스트

다음을 소유하지 않는다.

- credentials와 API key
- 모델 선택과 provider 인증
- MCP 인증 상태
- runtime session과 cache
- OpenClaw cron registry
- 개인 memory 내용
- Home Manager activation 순서

### `modules/openclaw`, `modules/codex`, `modules/claude`, `modules/pi`

다음을 소유한다.

- package 설치
- runtime별 설정과 plugin
- 생성 결과를 홈 디렉터리에 배치하는 Home Manager 선언
- runtime 전용 extension, hook, MCP 설정
- runtime이 요구하는 mutable state 초기화

공통 규칙이나 공통 skill의 원문을 소유하지 않는다.

### `gytkk/ws`

별도 저장소로 유지하며 다음을 소유한다.

- OpenClaw active workspace
- `SOUL.md`, `IDENTITY.md`, `USER.md`, `MEMORY.md`
- daily memory와 QMD 대상 문서
- workspace 전용 skill
- cron workflow와 self-improvement automation
- workspace에서만 의미가 있는 `AGENTS.md`

`ws`는 `agent-core`의 Python 구현이나 `nix-flakes` 내부 경로에 의존하지 않는다. OpenClaw module이 `ws`를 workspace로 연결한다.

## 의존성 방향

```text
agent-core Python package
        ↓ materialize
runtime별 immutable output tree
        ↓ install
modules/openclaw | modules/codex | modules/claude | modules/pi
        ↓
~/.openclaw | ~/.codex | ~/.claude | ~/.pi
```

허용하는 의존성은 다음과 같다.

```text
modules/* -> agent-core
flake packages/apps/checks -> agent-core
OpenClaw runtime -> ws
```

다음 의존성은 만들지 않는다.

```text
agent-core -> modules/*
agent-core -> ws의 개인 memory
agent-core -> runtime home directory
ws -> nix-flakes 내부 구현
runtime A -> runtime B의 session 또는 credentials
```

## Python interface

Python 구현 하나가 materialization을 담당한다. Nix와 Python에 같은 render 규칙을 중복 구현하지 않는다.

초기 command surface는 다음 세 개로 제한한다.

```bash
agent-core render --runtime openclaw --output <dir>
agent-core render --runtime codex --output <dir>
agent-core render --runtime claude --output <dir>
agent-core render --runtime pi --output <dir>
agent-core check
agent-core doctor --runtime <name>
```

- `render`는 source tree와 manifest를 읽고 deterministic output tree를 만든다.
- `check`는 manifest, rule, skill, generated marker와 runtime별 기대 결과를 검증한다.
- `doctor`는 설치 후 runtime이 기대 경로를 실제로 발견하는지 읽기 전용으로 진단한다.

`render`의 핵심 구현은 경로별 bytes map을 반환하는 pure module로 둔다. 파일 쓰기와 CLI parsing은 별도 module에 둔다. 테스트는 caller와 같은 interface를 사용한다.

## Manifest

`agent-core/manifest.toml`은 resource와 runtime 조합을 선언한다. credentials, 홈 디렉터리 절대 경로, host별 값은 포함하지 않는다.

초기 schema는 다음 정보만 다룬다.

- 공유 rule의 순서
- runtime별 추가 rule
- 공통 skill root
- runtime별 skill include/exclude
- runtime별 output layout
- generated marker

MVP에서는 runtime별 skill allowlist와 exclude list를 manifest에서 관리한다. 각 `SKILL.md`에 새로운 호환성 metadata를 일괄 추가하는 작업은 실제로 필터가 복잡해질 때 검토한다.

## Runtime별 출력

### OpenClaw

```text
openclaw/
└── AGENTS.md
```

공통 규칙과 OpenClaw adapter를 합성한다. Home Manager는 결과를 각 OpenClaw `agentDir`에 설치한다. `ws/AGENTS.md`, `SOUL.md`, memory, workspace skill은 OpenClaw가 기존처럼 직접 읽는다.

### Codex

```text
codex/
├── AGENTS.md
└── skills/
```

Home Manager는 `AGENTS.md`를 `~/.codex/AGENTS.md`에 설치하고, skill tree를 Codex가 발견하는 user skill root에 연결한다. Codex 전용 설정과 hook은 `modules/codex/`에 남긴다.

### Claude Code

```text
claude/
├── CLAUDE.md
└── skills/
```

Home Manager는 결과를 `~/.claude/CLAUDE.md`와 `~/.claude/skills/`에 설치한다. plugin과 marketplace 설정은 `modules/claude/`에 남긴다.

### Pi

```text
pi/
├── AGENTS.md
├── APPEND_SYSTEM.md
└── skills/
```

기존처럼 operating invariants는 `APPEND_SYSTEM.md`에 두고 나머지 공통 규칙과 Pi adapter를 `AGENTS.md`로 합성한다. Pi extension, model, MCP, theme 설정은 `modules/pi/`에 남긴다.

## Nix 연결

`agent-core/nix/package.nix`는 Python package를 빌드한다. flake는 package와 app을 노출한다.

예상 output은 다음과 같다.

```text
packages.<system>.agent-core
apps.<system>.agent-core
checks.<system>.agent-core-tests
checks.<system>.agent-core-render
```

각 runtime module은 build derivation 안에서 `agent-core render`를 실행한 결과를 `home.file` source로 사용한다. Nix evaluation 중에 mutable checkout이나 홈 디렉터리를 읽지 않는다.

개발 중에는 `uv run`으로 빠르게 테스트하고, Nix 검증은 package와 module 연결이 바뀐 단계에서만 실행한다.

## 기존 코드 이동

### 기존 `gytkk/agent-core`

다음 구현을 재사용한다.

- typed config loading
- generated marker 처리
- skill resolution
- path-to-bytes materialization
- 안전한 writer와 drift check
- CLI와 테스트 구조

`.agent/`에서 `.claude/`로만 변환하는 가정은 제거한다. canonical input은 `agent-core/manifest.toml`, `rules/`, `skills/`, `adapters/`가 된다.

기존 GitHub 저장소를 archive하거나 삭제하는 작업은 migration과 검증이 끝난 뒤 별도 승인을 받아 수행한다.

### 기존 `modules/agent-prompts`

다음 순서로 이동한다.

1. `rules/OPERATING.md`, `rules/PROSE.md`, 공유 `AGENTS.md` 내용을 분류한다.
2. runtime 중립 규칙을 `agent-core/rules/`로 이동한다.
3. runtime 전용 문장은 해당 adapter로 이동한다.
4. `skills/`를 `agent-core/skills/`로 이동한다.
5. Python renderer가 현재 `lib.nix`와 `skills.nix`의 결과를 재현하게 한다.
6. 네 runtime module이 새 output을 사용하도록 하나씩 전환한다.
7. 모든 runtime 검증 후 `modules/agent-prompts`의 중복 구현을 제거한다.

전환 중에는 기존 경로를 호환 layer로 장기간 유지하지 않는다. 한 runtime씩 새 interface로 옮기고 검증한 뒤 다음 runtime으로 진행한다.

## 구현 단계

### 1. 기준선 고정

- 현재 생성된 Claude, Codex, Pi instruction 파일을 fixture로 저장한다.
- 현재 공통 skill 이름과 source를 기록한다.
- OpenClaw의 workspace 및 agentDir loading 상태를 기록한다.
- 기존 `agent-core` 최신 commit과 테스트 결과를 기록한다.

완료 조건:

- 변경 전 runtime별 instruction과 skill 목록을 테스트에서 비교할 수 있다.

### 2. package 이전

- 기존 `agent-core` Python package를 최상위 `agent-core/`로 이전한다.
- import와 테스트가 monorepo 내부 경로에서 동작하게 한다.
- 기존 테스트를 먼저 그대로 통과시킨다.

완료 조건:

- `uv run --project agent-core -m pytest agent-core/tests`가 통과한다.
- 이 단계에서는 runtime 설치 결과가 달라지지 않는다.

### 3. 범용 materializer 도입

- hardcoded `.agent`와 `.claude` 경로를 manifest 기반 input/output으로 교체한다.
- runtime adapter interface를 추가한다.
- 네 runtime output tree에 대한 golden test를 추가한다.
- 같은 입력으로 반복 실행했을 때 byte 단위로 같은 결과가 나오는지 검증한다.

완료 조건:

- 네 runtime fixture가 생성된다.
- stale generated file만 정리하며 사람이 작성한 파일은 건드리지 않는다.

### 4. 공통 rules와 skills 이전

- `modules/agent-prompts`의 공통 원문을 `agent-core/`로 이동한다.
- 현재 render 순서와 Pi의 `APPEND_SYSTEM.md` 분리를 보존한다.
- skill 이름 충돌과 runtime별 제외를 검증한다.

완료 조건:

- 새 renderer 결과가 기존 runtime 파일과 의미상 동일하다.
- 공통 원문은 `agent-core/` 한 곳에만 있다.

### 5. Nix package와 checks 연결

- `agent-core/nix/package.nix`를 추가한다.
- flake package, app, checks를 노출한다.
- Nix build에서 renderer가 네 output tree를 생성하게 한다.

완료 조건:

- Python 테스트와 render check가 flake check에 포함된다.
- build가 홈 디렉터리와 mutable runtime state를 읽지 않는다.

### 6. runtime module 전환

다음 순서로 한 module씩 전환한다.

1. Pi
2. Claude Code
3. Codex
4. OpenClaw

Pi는 현재 shared rule 합성과 skill farm 구조가 명시적이어서 첫 adapter 검증 대상으로 사용한다. 각 module 전환은 별도 commit으로 만든다.

완료 조건:

- 전환한 runtime의 instruction과 skill discovery가 확인된다.
- runtime별 settings, plugin, extension 동작은 변경되지 않는다.

### 7. 중복 제거

- 사용되지 않는 `modules/agent-prompts/lib.nix`, `skills.nix`, 원본 rule과 skill을 제거한다.
- module 문서와 루트 architecture 문서를 새 구조에 맞춘다.
- 기존 `agent-core` 저장소 처리 방법을 결정한다.

완료 조건:

- 공통 rule과 skill의 정본이 한 곳뿐이다.
- 네 runtime module에 공통 원문 복사본이 없다.

## 검증 전략

좁은 검증부터 실행한다.

```bash
uv run --project agent-core -m pytest agent-core/tests
uv run --project agent-core agent-core check
nix build .#agent-core
nix flake check --no-build
```

runtime별 구조 검증은 모델 호출 없이 수행한다.

- 생성된 instruction 파일의 section 순서
- runtime 전용 adapter 포함 여부
- 다른 runtime adapter가 섞이지 않았는지 여부
- skill 이름, 개수, source와 충돌
- generated marker와 stale file 처리
- Home Manager source가 예상 derivation을 가리키는지 여부

설치 후 읽기 전용 smoke test에서는 각 CLI가 보고하는 context와 skill 경로를 확인한다. 실제 `home-manager switch`는 사용자 실행 단계로 남긴다.

## 위험과 대응

### 규칙 순서가 달라지는 문제

현재 runtime마다 operating rule을 배치하는 위치가 다르다. fixture와 golden test로 순서를 고정한다.

### skill이 의도하지 않은 runtime에 노출되는 문제

manifest의 include/exclude를 fail-closed로 처리한다. 알 수 없는 runtime 이름이나 존재하지 않는 skill 이름은 오류로 처리한다.

### Nix와 Python에서 동작이 달라지는 문제

Nix는 Python renderer를 호출하고 자체 render 규칙을 갖지 않는다. Nix module은 결과 배치만 담당한다.

### generated 파일을 사용자가 수정하는 문제

모든 생성 파일에 marker를 넣고 `check`가 drift를 실패로 보고한다. 사용자 편집 대상은 `agent-core/rules`, `skills`, `adapters`, `manifest.toml`로 제한한다.

### 회사나 비 Nix 환경에서 사용하기 어려운 문제

Python package는 stdlib-only runtime을 유지하고 Nix 없이 실행할 수 있게 한다. 필요한 경우 monorepo의 `agent-core/`만 추출하거나 package artifact로 제공할 수 있게 경로 의존성을 제한한다.

## 최종 완료 조건

- 공통 rule과 portable skill의 정본이 `agent-core/` 한 곳에 있다.
- Python renderer 하나가 네 runtime output을 만든다.
- Nix module은 runtime 설치와 설정만 담당한다.
- `ws`의 memory와 automation은 기존 별도 저장소에 남는다.
- 네 runtime이 동일한 공통 core와 각자의 adapter를 함께 읽는다.
- Python 테스트, Nix build, flake check와 runtime별 구조 검증이 통과한다.
- credentials, session, cache와 개인 memory가 materialized output에 포함되지 않는다.
