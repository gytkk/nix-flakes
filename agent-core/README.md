# Agent core 통합 계획

## 목적

`agent-core`를 `nix-flakes` 저장소의 최상위 `agent-core/`에서 관리한다. 독립 Python package가 공통 규칙, portable skill, runtime별 instruction adapter를 deterministic output tree로 materialize한다. `modules/openclaw`, `modules/codex`, `modules/claude`, `modules/pi`는 runtime 전용 resource를 입력으로 제공하고 생성 결과를 설치한다.

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
│   ├── skills/                 # 수정 없이 여러 runtime에 배포하는 portable skill
│   ├── adapters/               # runtime 전용 instruction 원문
│   ├── schema/
│   ├── nix/
│   └── tests/
├── modules/
│   ├── openclaw/
│   ├── codex/
│   │   └── skills/             # Codex 전용 skill
│   ├── claude/
│   │   └── marketplace/skills/ # Claude plugin 전용 skill
│   └── pi/
│       └── skills/             # Pi 전용 skill
└── flake.nix
```

`agent-core/`는 Home Manager module이 아니다. Nix 없이 실행하고 테스트할 수 있는 독립 Python package다. 각 runtime module은 이 package의 interface를 호출하고 결과를 설치한다.

## 용어와 소유권

### Skill 분류

Portable skill은 디렉터리를 수정하지 않고 여러 runtime에 설치해도 의미와 실행 방법이 유지되는 Agent Skill이다. 특정 runtime의 tool, extension, SDK, metadata, 설치 형식에 의존하면 runtime 전용 skill로 분류한다. 특정 OpenClaw workspace의 데이터나 automation에 의존하면 workspace 전용 skill로 분류한다.

배포 가능한 skill 디렉터리 전체를 기준으로 분류한다. 일부 내용이 공통이어도 실행에 runtime 전용 기능이 필요하면 해당 skill 전체를 runtime 전용으로 둔다. 공통 본문과 runtime wrapper를 합성하는 기능은 MVP에 포함하지 않는다.

### 소유권의 의미

이 문서에서 소유권은 파일 권한이 아니라 다음 책임을 뜻한다.

- 원문을 수정하는 정본 위치
- 요구사항이 바뀌었을 때 수정할 module
- 형식, 충돌, 호환성을 검증할 module
- runtime이나 format 변경에 대응할 module

생성 결과를 설치하는 module이 원문까지 소유하는 것은 아니다. 예를 들어 Pi module은 portable skill을 설치하지만 그 원문은 수정하지 않는다.

### `agent-core/`

다음을 소유한다.

- 모든 coding agent가 공유하는 운영 규칙
- 공통 prose 규칙과 memory 접근 계약
- portable Agent Skills
- runtime별 instruction adapter 원문
- portable skill 선택, skill 병합, 충돌 처리 규칙
- deterministic materialization
- manifest와 schema
- source와 runtime 전용 입력이 없는 core output 검증
- Python 단위 테스트와 통합 테스트

다음을 소유하지 않는다.

- runtime 전용 skill 원문
- credentials와 API key
- 모델 선택과 provider 인증
- MCP 인증 상태
- runtime session과 cache
- OpenClaw cron registry
- 개인 memory 내용
- runtime 홈 경로와 Home Manager activation 순서
- runtime CLI를 이용한 설치 후 smoke test

### `modules/openclaw`, `modules/codex`, `modules/claude`, `modules/pi`

다음을 소유한다.

- runtime package 설치 또는 user-managed runtime의 host integration
- runtime별 설정과 plugin
- runtime 전용 skill 원문
- renderer에 전달할 runtime 전용 skill root
- 실제 runtime 전용 입력을 포함한 최종 output 검증
- 생성 결과를 runtime 경로에 배치하는 Home Manager 선언
- runtime 전용 extension, hook, MCP 설정
- runtime이 요구하는 mutable state 초기화
- runtime이 생성 결과를 실제로 발견하는지 확인하는 smoke test

공통 규칙이나 portable skill의 원문과 render 알고리즘은 소유하지 않는다.

### `gytkk/ws`

별도 저장소로 유지하며 다음을 소유한다.

- OpenClaw active workspace
- workspace의 `AGENTS.md`, `SOUL.md`, `IDENTITY.md`, `USER.md`, `MEMORY.md`
- daily memory와 QMD 대상 문서
- workspace 전용 skill
- cron workflow와 self-improvement automation

`ws`는 `agent-core`의 Python 구현이나 `nix-flakes` 내부 경로에 의존하지 않는다. User-managed OpenClaw configuration이 `ws`를 active workspace로 지정한다. OpenClaw module은 `openclaw.json`이나 workspace 선택을 소유하지 않는다.

## 의존성 방향

```text
agent-core source + runtime module이 제공한 전용 skill root
        ↓ materialize
runtime별 immutable output tree
        ↓ install
modules/openclaw | modules/codex | modules/claude | modules/pi
        ↓
~/.openclaw | ~/.codex | ~/.claude | ~/.pi
```

허용하는 의존성은 다음과 같다.

```text
modules/* -> agent-core package와 render interface
flake packages/apps/checks -> agent-core
OpenClaw runtime configuration -> ws
OpenClaw context injection plugin -> agent-core의 OpenClaw output
```

다음 의존성은 만들지 않는다.

```text
agent-core source -> modules/* 경로
agent-core -> ws의 개인 memory
agent-core -> 암묵적인 runtime 홈 경로
ws -> nix-flakes 내부 구현
runtime A -> runtime B의 session 또는 credentials
```

Runtime module은 자신의 skill root를 command argument로 전달한다. `agent-core`는 해당 경로를 입력으로 처리하지만 `modules/*`의 위치나 구조를 내장하지 않는다.

## Interface

Python 구현 하나가 materialization을 담당한다. Nix와 Python에 같은 render 규칙을 중복 구현하지 않는다.

초기 command surface는 다음 세 개로 제한한다.

```bash
agent-core render --runtime <name> [--runtime-skill-root <dir>] --output <dir>
agent-core check
agent-core verify-install --expected <dir> --actual <dir>
```

- `render`는 source tree, manifest, 선택적으로 전달된 runtime 전용 skill root를 읽고 deterministic output tree를 만든다. `--runtime-skill-root`는 필요하면 반복해서 전달할 수 있다.
- `check`는 manifest, rule, portable skill, adapter, generated marker와 runtime 전용 입력이 없는 core golden output을 검증한다. 홈 디렉터리와 module 경로는 읽지 않는다.
- `verify-install`은 명시적으로 전달받은 expected tree와 actual tree의 파일, marker, symlink, skill 구조를 비교한다. runtime 이름이나 기본 홈 경로를 추론하지 않는다.

Runtime이 instruction과 skill을 실제 context에서 발견하는지는 각 runtime module의 smoke test가 확인한다. `agent-core doctor`는 만들지 않는다. 특히 기존 `openclaw doctor`와 이름 및 책임이 겹치지 않게 한다.

핵심 Python interface는 다음 형태의 경로별 bytes map을 반환하는 pure module로 둔다.

```python
materialize(
    runtime: str,
    runtime_skill_roots: Sequence[Path] = (),
) -> Mapping[PurePosixPath, bytes]
```

파일 쓰기와 CLI parsing은 이 interface 밖에 둔다. 테스트는 caller와 같은 interface를 사용한다.

## Skill 병합

Skill 병합은 각 Nix module에 중복 구현하지 않고 Python renderer 한 곳에서 수행한다.

1. manifest에서 runtime의 portable skill allowlist를 읽는다.
2. `agent-core/skills/`에서 allowlist에 포함된 skill을 선택한다.
3. caller가 전달한 runtime 전용 skill root의 skill을 추가한다.
4. 최종 skill 이름 충돌과 `SKILL.md` 형식을 검증한다.
5. 정렬된 경로별 bytes map을 생성한다.

충돌 규칙은 다음과 같다.

- 최종 skill 이름이 중복되면 오류로 처리한다.
- runtime 전용 skill이 portable skill을 대체해야 하면 manifest의 portable allowlist에서 해당 이름을 제외하고 runtime skill root에서 제공한다.
- allowlist가 존재하지 않는 portable skill을 가리키면 오류로 처리한다.
- 암묵적인 덮어쓰기나 runtime별 우선순위를 두지 않는다.

Claude marketplace처럼 별도의 plugin 설치 방식으로 제공되는 skill은 renderer에 전달하지 않는다. 해당 plugin과 skill은 Claude module이 관리한다.

OpenClaw workspace skill은 materialized output에 포함하지 않는다. OpenClaw가 정의한 workspace skill 우선순위를 따르며, runtime smoke test에서 managed skill과 workspace skill의 중복 이름을 보고한다.

## Manifest와 adapter

`agent-core/manifest.toml`은 공통 resource와 runtime별 output 조합을 선언한다. credentials, 홈 디렉터리 절대 경로, host별 값, module 경로는 포함하지 않는다.

초기 schema는 다음 정보만 다룬다.

- 공유 rule의 순서
- runtime별 adapter 원문
- runtime별 portable skill allowlist
- runtime별 output layout
- generated marker version

Skill 선택은 allowlist 하나만 사용한다. include와 exclude를 함께 두지 않는다. 각 `SKILL.md`에 호환성 metadata를 추가하는 작업은 실제로 선택 조건이 복잡해질 때 검토한다.

예상 형태는 다음과 같다.

```toml
[runtimes.pi]
rules = [
  "rules/shared.md",
  "adapters/pi/AGENTS.md",
]
portable_skills = [
  "codebase-design",
  "research",
  "tdd",
]

[runtimes.pi.output]
instructions = "AGENTS.md"
system_append = "APPEND_SYSTEM.md"
skills = "skills"
```

Adapter는 runtime 전용 instruction 원문만 담는다.

```text
agent-core/adapters/openclaw/AGENTS.md
agent-core/adapters/codex/AGENTS.md
agent-core/adapters/claude/CLAUDE.md
agent-core/adapters/pi/AGENTS.md
```

Adapter는 홈 경로, module 경로, skill 선택, plugin 설정, Python 분기를 소유하지 않는다. Renderer는 manifest 해석, skill 병합, 충돌 검사, deterministic output 생성을 담당하지만 runtime 홈 경로나 runtime CLI를 알지 않는다.

## Runtime별 출력과 설치

### OpenClaw

```text
openclaw/
├── AGENTS.core.md
└── skills/
```

OpenClaw의 workspace는 instruction과 memory를 보관하고, `agentDir`은 auth, model registry, session과 runtime state를 보관한다. 따라서 `AGENTS.core.md`를 `agentDir`에 설치하지 않는다. 이 구분은 OpenClaw의 [Agent workspace](https://docs.openclaw.ai/concepts/agent-workspace)와 [Multi-agent routing](https://docs.openclaw.ai/concepts/multi-agent) 문서를 따른다.

Home Manager는 `AGENTS.core.md`를 `stateDir` 아래의 module 관리 경로에 설치하고 portable skill tree를 OpenClaw managed skill root에 연결한다. `modules/openclaw`는 OpenClaw context injection plugin을 설치한다. Plugin은 지원되는 typed prompt hook을 사용해 공통 core instruction과 active workspace의 `AGENTS.md`를 정해진 순서로 context에 포함한다. 구현 전에 설치된 OpenClaw 버전의 hook interface를 확인한다.

OpenClaw 연결에서 각 영역은 다음 책임을 갖는다.

- `agent-core`는 `AGENTS.core.md`와 managed portable skill tree를 생성한다.
- `modules/openclaw`는 생성 결과, context injection plugin, plugin이 읽을 output 경로를 설치한다.
- User-managed `openclaw.json`은 `ws`를 workspace로 지정하고 필요한 plugin allowlist를 관리한다.
- `ws`는 workspace `AGENTS.md`, persona, memory, workspace skill을 계속 소유한다.

Plugin은 공통 instruction을 정확히 한 번 포함해야 한다. Plugin이 비활성화되거나 output을 찾지 못하면 로그와 smoke test에서 명시적으로 실패를 보고한다. 합성 순서, 누락, 중복, 여러 agent의 서로 다른 workspace를 fixture로 검증한다. 설치 후에는 OpenClaw context 진단과 skill 상태를 이용해 실제 discovery를 확인한다.

### Codex

```text
codex/
├── AGENTS.md
└── skills/
```

Codex module은 `modules/codex/skills/`를 `--runtime-skill-root`로 전달한다. Renderer는 portable allowlist와 Codex 전용 skill을 하나의 최종 tree로 합친다. Module은 `AGENTS.md`와 skill tree를 Codex가 발견하는 관리 경로에 설치한다. Codex 설정, hook, plugin과 activation은 `modules/codex/`에 남긴다.

### Claude Code

```text
claude/
├── CLAUDE.md
└── skills/
```

Renderer는 portable allowlist로 Claude user skill tree를 생성한다. Home Manager는 `CLAUDE.md`와 portable skill tree를 Claude가 발견하는 user 경로에 설치한다. Claude 전용 marketplace skill은 생성 tree에 합치지 않고 `modules/claude/marketplace/skills/`와 plugin 설정으로 관리한다.

### Pi

```text
pi/
├── AGENTS.md
├── APPEND_SYSTEM.md
└── skills/
```

Pi module은 `modules/pi/skills/`를 `--runtime-skill-root`로 전달한다. 기존처럼 operating invariants는 `APPEND_SYSTEM.md`에 두고 나머지 공통 규칙과 Pi adapter를 `AGENTS.md`로 합성한다. Renderer는 portable allowlist와 Pi 전용 skill을 하나의 최종 tree로 합친다. Pi extension, model, MCP, theme 설정은 `modules/pi/`에 남긴다.

## Nix 연결

`agent-core/nix/package.nix`는 Python package를 빌드한다. Flake는 package와 app을 노출한다.

예상 output은 다음과 같다.

```text
packages.<system>.agent-core
apps.<system>.agent-core
checks.<system>.agent-core-tests
checks.<system>.agent-core-render
```

각 runtime module은 build derivation 안에서 `agent-core render`를 실행한다. Pi와 Codex처럼 repository-managed runtime 전용 skill이 있는 module은 자신의 skill root를 argument로 전달한다. `agent-core`는 module 경로를 import하거나 추론하지 않는다.

Nix module은 생성된 immutable output을 `home.file` 등의 runtime 설치 선언에서 사용한다. Nix evaluation과 renderer는 홈 디렉터리, mutable checkout state, runtime state를 읽지 않는다.

개발 중에는 `uv run`으로 빠르게 테스트한다. Nix package 또는 module 연결이 바뀐 단계에서만 필요한 Nix 평가를 실행한다.

## Immutable output과 직접 설치

MVP는 Nix derivation의 비어 있는 output 디렉터리에 deterministic tree를 생성하고 Home Manager가 설치하는 방식만 지원한다. Nix store의 생성 파일은 immutable하며 이전 generation 교체와 설치 대상 관리는 Home Manager가 담당한다.

일반 홈 디렉터리에 파일을 직접 쓰는 비 Nix 설치는 별도 배포 방식이다. 이 방식에는 generated marker, 사용자 수정 감지, stale 파일 정리, 삭제 안전성이 필요하다. 이러한 동작을 `render`나 `check`에 섞지 않는다.

비 Nix 직접 설치가 필요해지면 다음 command를 별도 설계한다.

```bash
agent-core sync --runtime <name> [--runtime-skill-root <dir>] --output <dir>
```

`sync`만 generated marker를 근거로 stale 파일을 정리하고 drift를 검사한다. MVP에서는 기존 `agent-core`의 safe writer와 output drift 기능을 이전하지 않는다. Source와 golden output의 drift는 `check`, 명시적인 설치 tree 비교는 `verify-install`, runtime discovery는 module smoke test가 담당한다.

## 기존 코드 이동

### 기존 `gytkk/agent-core`

다음 구현을 재사용한다.

- typed config loading
- generated marker 처리
- skill resolution
- path-to-bytes materialization
- CLI와 테스트 구조

`.agent/`에서 `.claude/`로만 변환하는 가정은 제거한다. 정본 입력은 `agent-core/manifest.toml`, `rules/`, `skills/`, `adapters/`와 caller가 명시적으로 전달한 runtime skill root다.

Safe writer, stale cleanup, 설치 대상 drift check는 직접 설치용 `sync`를 도입할 때 별도로 이전한다.

기존 GitHub 저장소를 archive하거나 삭제하는 작업은 migration과 검증이 끝난 뒤 별도 승인을 받아 수행한다.

### 기존 `modules/agent-prompts`

다음 순서로 이동한다.

1. `rules/OPERATING.md`, `rules/PROSE.md`, 공유 `AGENTS.md` 내용을 분류한다.
2. runtime 중립 규칙을 `agent-core/rules/`로 이동한다.
3. runtime 전용 instruction을 해당 adapter로 이동한다.
4. 수정 없이 여러 runtime에 배포할 수 있는 skill만 `agent-core/skills/`로 이동한다.
5. Pi, Codex, Claude 전용 skill은 해당 runtime module에 남긴다.
6. Python renderer가 현재 instruction 합성과 shared skill 배치 결과를 재현하게 한다.
7. 네 runtime module이 새 output을 사용하도록 하나씩 전환한다.
8. 모든 runtime 검증 후 `modules/agent-prompts`의 중복 구현을 제거한다.

전환 중에는 기존 경로를 호환 layer로 장기간 유지하지 않는다. 한 runtime씩 새 interface로 옮기고 검증한 뒤 다음 runtime으로 진행한다.

## 구현 단계

### 1. 기준선 고정

- 현재 생성된 Claude, Codex, Pi instruction 파일을 fixture로 저장한다.
- portable skill과 runtime 전용 skill의 현재 이름, source, 설치 경로를 기록한다.
- OpenClaw의 active workspace, workspace bootstrap 파일, managed skill root, 실제 context loading 상태를 기록한다.
- 기존 `agent-core` 최신 commit과 테스트 결과를 기록한다.

완료 조건:

- 변경 전 runtime별 instruction source와 skill 목록을 테스트에서 비교할 수 있다.
- OpenClaw에서 workspace와 `agentDir`의 역할을 구분한 기준선이 있다.

### 2. Package 이전

- 기존 `agent-core` Python package를 최상위 `agent-core/`로 이전한다.
- import와 테스트가 monorepo 내부 경로에서 동작하게 한다.
- 기존 테스트를 먼저 그대로 통과시킨다.

완료 조건:

- `uv run --project agent-core -m pytest agent-core/tests`가 통과한다.
- 이 단계에서는 runtime 설치 결과가 달라지지 않는다.

### 3. 범용 materializer 도입

- hardcoded `.agent`와 `.claude` 경로를 manifest 기반 input/output으로 교체한다.
- `materialize(runtime, runtime_skill_roots)` interface를 추가한다.
- portable allowlist와 runtime skill root 병합을 구현한다.
- 이름 충돌, 존재하지 않는 allowlist 항목, 잘못된 `SKILL.md`를 오류로 처리한다.
- 네 runtime의 core output에 대한 golden test를 추가한다.
- 테스트 전용 runtime skill fixture로 병합과 충돌 처리를 검증한다.
- 같은 입력으로 반복 실행했을 때 byte 단위로 같은 결과가 나오는지 검증한다.

완료 조건:

- 실제 module 경로에 의존하지 않는 네 runtime core fixture가 생성된다.
- Renderer가 홈 디렉터리나 module 경로를 내장하지 않는다.
- 최종 skill tree에 암묵적인 덮어쓰기가 없다.

### 4. 공통 rules와 portable skills 이전

- `modules/agent-prompts`의 공통 원문을 `agent-core/`로 이동한다.
- 현재 render 순서와 Pi의 `APPEND_SYSTEM.md` 분리를 보존한다.
- Runtime 전용 skill은 각 module에 남기고 renderer 입력으로 전달한다.

완료 조건:

- Runtime 전용 skill root가 없는 core renderer 결과가 승인된 golden fixture와 byte 단위로 일치한다.
- 공통 원문과 portable skill의 정본은 `agent-core/` 한 곳에만 있다.
- Runtime 전용 skill의 정본은 해당 module에만 있다.

### 5. Nix package와 checks 연결

- `agent-core/nix/package.nix`를 추가한다.
- Flake package, app, checks를 노출한다.
- Nix build에서 renderer가 네 output tree를 생성하게 한다.
- Pi와 Codex build가 각 module의 skill root를 명시적으로 전달하게 한다.
- 실제 runtime skill root를 포함한 최종 output을 Nix check의 golden fixture와 비교한다.

완료 조건:

- Python core check와 Nix의 최종 runtime output check가 flake check에 포함된다.
- Build가 홈 디렉터리와 mutable runtime state를 읽지 않는다.
- Nix에는 별도의 instruction 또는 skill 합성 규칙이 없다.

### 6. Runtime module 전환

다음 순서로 한 module씩 전환한다.

1. Pi
2. Claude Code
3. Codex
4. OpenClaw

Pi는 현재 shared rule 합성과 local skill 병합 구조가 명시적이어서 첫 검증 대상으로 사용한다. Claude marketplace skill은 기존 plugin 경로에 남긴다. Codex는 system skill 설치와 runtime 전용 skill 병합을 함께 검증한다. OpenClaw는 마지막에 context injection plugin, managed skill root, workspace context를 함께 검증한다. 각 module 전환은 별도 commit으로 만든다.

완료 조건:

- 전환한 runtime의 instruction과 skill discovery가 확인된다.
- Runtime별 settings, plugin, extension 동작은 변경되지 않는다.
- Module에 공통 render 로직이나 portable skill 원문이 없다.

### 7. 중복 제거

- 사용되지 않는 `modules/agent-prompts/lib.nix`, `skills.nix`, 공통 rule과 portable skill 원본을 제거한다.
- Module 문서와 루트 architecture 문서를 새 소유권에 맞춘다.
- 기존 `agent-core` 저장소 처리 방법을 결정한다.

완료 조건:

- 공통 rule과 portable skill의 정본이 한 곳뿐이다.
- Runtime 전용 skill의 정본이 해당 module에만 있다.
- 네 runtime module에 공통 원문 복사본이나 독자적인 merge 구현이 없다.

## 검증 전략

좁은 검증부터 실행한다.

```bash
uv run --project agent-core -m pytest agent-core/tests
uv run --project agent-core agent-core check
nix build .#agent-core
nix flake check --no-build
```

`agent-core check`는 모델 호출 없이 core source와 output을 검증한다.

- 생성된 instruction 파일의 section 순서
- 해당 runtime adapter 포함 여부
- 다른 runtime adapter가 섞이지 않았는지 여부
- portable allowlist
- skill 이름 충돌과 잘못된 `SKILL.md` 거부
- 같은 입력의 byte 단위 재현성
- generated marker

Nix check는 실제 module 입력을 포함한 최종 runtime output을 검증한다.

- runtime skill root의 최종 이름과 source
- core golden output과 runtime 전용 skill의 병합 결과
- Home Manager source가 예상 derivation을 가리키는지 여부

설치 tree는 명시적인 경로를 전달해 비교한다.

```bash
agent-core verify-install --expected <derivation-output> --actual <installed-root>
```

Runtime별 smoke test는 module이 소유한다.

- Pi, Codex, Claude Code가 보고하는 instruction과 skill 경로
- OpenClaw context에 공통 core와 workspace `AGENTS.md`가 각각 한 번 포함되는지 여부
- OpenClaw managed skill과 workspace skill의 이름 및 우선순위
- OpenClaw context injection plugin의 활성화 상태와 오류 로그

실제 `home-manager switch`는 사용자 실행 단계로 남긴다.

## 위험과 대응

### 규칙 순서가 달라지는 문제

현재 runtime마다 operating rule을 배치하는 위치가 다르다. Manifest가 순서를 선언하고 golden test가 생성 bytes를 고정한다.

### Skill이 의도하지 않은 runtime에 노출되는 문제

Manifest의 portable allowlist를 fail-closed로 처리한다. 알 수 없는 runtime 이름이나 존재하지 않는 portable skill 이름은 오류로 처리한다. Runtime skill root 사이의 이름 충돌도 오류로 처리한다.

### Runtime 전용 skill이 portable skill을 암묵적으로 덮어쓰는 문제

최종 이름 충돌은 실패한다. Runtime 전용 구현을 사용하려면 manifest allowlist에서 portable 구현을 명시적으로 제외한다.

### Nix와 Python에서 동작이 달라지는 문제

Nix는 Python renderer를 호출하고 자체 render 또는 merge 규칙을 갖지 않는다. Nix module은 runtime 전용 입력 전달과 생성 결과 배치만 담당한다.

### 생성 파일과 사용자 파일의 삭제 책임이 섞이는 문제

MVP는 Nix의 immutable output만 생성한다. Home Manager가 generation 교체와 설치 대상 관리를 담당한다. 일반 디렉터리의 stale cleanup은 향후 `sync` command에서 generated marker가 있는 파일로 제한한다.

### OpenClaw가 공통 instruction을 읽지 않는 문제

OpenClaw module은 `agentDir`이 아니라 context injection hook에서 공통 instruction을 연결한다. Plugin 활성화, output 경로, 합성 순서와 중복을 fixture와 runtime smoke test로 검증한다. Workspace 선택과 mutable plugin allowlist는 user-managed OpenClaw configuration이 소유한다.

### 회사나 비 Nix 환경에서 사용하기 어려운 문제

Python package는 stdlib-only runtime을 유지하고 Nix 없이 render와 check를 실행할 수 있게 한다. 필요한 경우 monorepo의 `agent-core/`만 추출하거나 package artifact로 제공할 수 있게 경로 의존성을 제한한다. 일반 디렉터리에 직접 설치하는 `sync`는 실제 요구가 생길 때 별도 interface로 추가한다.

## 최종 완료 조건

- 공통 rule과 portable skill의 정본이 `agent-core/` 한 곳에 있다.
- Runtime 전용 skill의 정본이 각 runtime module에 있다.
- Python renderer 하나가 portable skill과 명시적으로 전달된 runtime skill root를 병합한다.
- Manifest는 rule 순서, adapter 원문 참조, portable allowlist, output layout과 generated marker version만 선언한다.
- Adapter는 runtime 전용 instruction 원문만 담는다.
- Nix module은 runtime 전용 입력, 설치, 설정과 smoke test만 담당한다.
- `ws`의 instruction, memory, workspace skill과 automation은 별도 저장소에 남는다.
- OpenClaw 공통 instruction은 workspace가 아닌 runtime context injection seam을 통해 적용된다.
- `check`는 core source와 core golden output, Nix check는 실제 module 입력을 포함한 최종 output, `verify-install`은 명시적인 tree, module smoke test는 runtime discovery를 검증한다.
- Python 테스트, Nix build, flake check와 runtime별 구조 검증이 통과한다.
- Credentials, session, cache와 개인 memory가 materialized output에 포함되지 않는다.
