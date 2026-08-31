# Agent core

## 목적

`agent-core/`는 이 저장소에서 관리하는 coding-agent 공통 규칙, runtime adapter, shared skill의 canonical source다. 하나의 stdlib-only Python renderer가 manifest를 해석하고 Claude Code, Codex, Pi, OpenClaw용 immutable output tree를 생성한다.

Runtime module은 생성 결과를 설치한다. 공통 문서 조합, skill 선택, 검증 로직을 Nix나 runtime별 module에서 다시 구현하지 않는다.

## 구조

```text
agent-core/
├── pyproject.toml
├── uv.lock
├── manifest.toml
├── src/agent_core/       # Python API와 CLI
├── rules/                # Runtime에 독립적인 공통 규칙
├── adapters/             # Claude Code, Codex, Pi 전용 지침
├── skills/               # Shared skill의 canonical catalog
├── schema/               # Runtime output golden hash
├── nix/                  # Package와 render derivation helper
└── tests/
```

Shared skill은 runtime별 복사본이나 merge input 없이 `agent-core/skills/`에서 한 번 관리하는 skill이다. Shared catalog에 있다는 사실이 모든 runtime에 설치된다는 뜻은 아니다. `manifest.toml`의 allowlist가 각 runtime에 필요한 skill을 선택한다. 현재 공통 11개 skill에 더해 Codex는 `devils-advocate`와 `parallel-research-merge`, Pi는 두 skill과 `pi-agent`를 선택한다.

## 책임 경계

### Agent core

`agent-core/`는 다음을 소유한다.

- 공통 운영 규칙과 prose 규칙
- Runtime adapter 원문
- Shared skill 원문과 보조 파일
- Runtime별 문서 조합 순서와 skill allowlist
- Deterministic materialization과 generated marker
- Source validation, golden hash, tree comparison
- Python package, CLI, 단위 테스트, Nix package

`agent-core/`는 다음을 소유하지 않는다.

- Credentials, API key, provider 인증
- 모델 선택, MCP 인증 상태, session, cache
- Runtime 홈 경로와 Home Manager activation 순서
- OpenClaw의 mutable `openclaw.json`, workspace 선택, auth와 session state
- OpenClaw workspace의 `AGENTS.md`, persona, memory, workspace skill
- Claude marketplace plugin 원문
- Runtime CLI를 통한 설치 후 discovery 확인

### Runtime module

`modules/claude`, `modules/codex`, `modules/pi`, `modules/openclaw`은 다음을 소유한다.

- Runtime package 또는 user-managed runtime의 host integration
- Renderer output을 실제 runtime 경로에 설치하는 선언
- Runtime settings, plugin, extension, hook, MCP 설정
- Mutable state의 안전한 경계와 activation 순서
- Runtime이 설치 결과를 발견하는지 확인하는 smoke test

Runtime module은 공통 원문, shared skill 원문, 독자적인 render 또는 merge 알고리즘을 소유하지 않는다. Renderer는 manifest에 선언한 source만 선택한다.

## 의존성 방향

```text
agent-core source
        ↓ materialize
runtime별 immutable output tree
        ↓ install
modules/claude | modules/codex | modules/pi | modules/openclaw
        ↓
~/.claude | ~/.codex | ~/.pi | ~/.openclaw
```

허용하는 의존성은 다음과 같다.

```text
modules/* -> agent-core package와 render interface
flake packages/apps/checks -> agent-core
OpenClaw context plugin -> agent-core의 OpenClaw output
```

다음 의존성은 만들지 않는다.

```text
agent-core source -> modules/* 경로
agent-core -> 개인 memory 또는 runtime state
agent-core -> 암묵적인 runtime 홈 경로
runtime A -> runtime B의 session 또는 credentials
```

## Python interface

CLI는 다음 세 command를 제공한다.

```bash
agent-core render --runtime <name> --output <empty-dir>
agent-core check
agent-core verify-install --expected <dir> --actual <dir>
```

- `render`는 manifest와 canonical resource를 읽고 runtime별 shared skill allowlist에 맞는 output tree를 생성한다. Output 경로는 없거나 비어 있는 실제 디렉터리여야 한다.
- `check`는 manifest, rule, adapter, skill, generated marker, golden hash를 검증한다. 홈 디렉터리와 module 경로는 읽지 않는다.
- `verify-install`은 명시적으로 전달한 두 tree의 파일 내용, symlink 대상, 누락 경로, 추가 경로를 비교한다. Runtime 이름이나 기본 홈 경로를 추론하지 않는다.

핵심 API는 경로별 bytes map을 반환한다.

```python
materialize(runtime: str) -> Mapping[PurePosixPath, bytes]
```

파일 쓰기와 CLI parsing은 이 API 밖에 둔다. Renderer는 manifest allowlist에 있는 shared skill만 선택한다. 같은 source, manifest, runtime은 byte 단위로 같은 결과를 만들어야 한다.

## Manifest

`manifest.toml`은 다음 정보만 선언한다.

- Manifest와 generated marker version
- 지원 runtime
- Runtime별 output 문서 경로와 source 순서
- Runtime별 shared skill allowlist
- Runtime별 skill output root

Credentials, 절대 홈 경로, host 값, module 경로는 manifest에 넣지 않는다. Unknown key, unknown runtime, unsafe path, 중복 output, 존재하지 않는 source나 skill은 오류다.

Skill 검증은 각 디렉터리의 `SKILL.md` frontmatter에서 `name`과 `description`을 요구한다. `name`은 디렉터리 이름과 같아야 한다. Symlink와 output tree를 벗어나는 경로는 거부한다.

## Runtime output

모든 output root에는 `.agent-core-generated` marker가 있다. Skill 파일에도 generated marker를 넣기 때문에 생성 결과를 canonical source로 오인하지 않아야 한다.

### Claude Code

```text
CLAUDE.md
skills/
```

`CLAUDE.md`는 공통 operating rule, 공통 agent rule, prose rule, Claude adapter 순서로 생성한다. Home Manager는 문서와 선택된 shared skill tree를 `~/.claude/`에 설치한다. `devils-advocate` command와 agent는 local marketplace plugin이 별도로 소유하므로 Claude allowlist에는 넣지 않는다.

### Codex

```text
AGENTS.md
skills/
```

`AGENTS.md`는 공통 operating rule, 공통 agent rule, prose rule, Codex adapter 순서로 생성한다. Codex allowlist는 shared catalog의 `devils-advocate`와 `parallel-research-merge`를 포함한다. NixOS는 최종 skill tree를 `/etc/codex/skills`에 설치하고 Standalone Home Manager 환경도 같은 output을 system 경로에 연결한다.

### Pi

```text
AGENTS.md
APPEND_SYSTEM.md
skills/
```

Pi는 operating invariant를 `APPEND_SYSTEM.md`로 분리한다. `AGENTS.md`에는 공통 agent rule, prose rule, Pi adapter만 포함한다. Pi allowlist는 shared catalog의 `devils-advocate`, `parallel-research-merge`, `pi-agent`를 포함한다.

### OpenClaw

```text
AGENTS.core.md
skills/
```

OpenClaw output에는 runtime adapter가 없다. `AGENTS.core.md`는 세 공통 rule을 포함한다. Home Manager는 instruction과 선택된 shared skill tree를 `~/.local/share/openclaw/agent-core/`에 설치한다. Mutable OpenClaw config는 skill 경로를 `skills.load.extraDirs`로 로드하고, systemd drop-in은 instruction 경로를 `AGENT_CORE_OPENCLAW_INSTRUCTIONS`로 전달한다.

`modules/openclaw`의 `agent-core-context` plugin은 `before_prompt_build` hook에서 `prependSystemContext`를 반환한다. Plugin은 OpenClaw system prompt를 교체하지 않고 workspace `AGENTS.md`를 생성하거나 수정하지 않는다. Mutable `openclaw.json`은 plugin enable, allowlist, conversation access를 계속 소유한다.

## Nix 연결

`agent-core/nix/package.nix`는 wheel에 manifest와 canonical resource를 포함한 Python application을 만든다. `agent-core/nix/render.nix`는 runtime 이름을 받아 build derivation 안에서 renderer를 실행한다.

Flake는 다음 output을 노출한다.

```text
packages.<system>.agent-core
apps.<system>.agent-core
checks.<system>.agent-core
checks.<system>.agent-core-renders
```

Runtime module은 `render.nix`가 만든 immutable tree에서 필요한 파일을 설치한다. `checks.<system>.agent-core-renders`는 네 final output의 recursive golden hash와 Home Manager/NixOS source wiring을 검증한다. Nix evaluation과 renderer는 홈 디렉터리, checkout 밖의 mutable state, runtime state를 읽지 않는다.

## Immutable output과 직접 설치

현재 구현은 Nix derivation의 비어 있는 output 디렉터리에 deterministic tree를 생성하고 Home Manager가 설치하는 방식만 지원한다. 일반 홈 디렉터리에 직접 쓰는 `sync` command는 제공하지 않는다.

직접 설치에는 사용자 수정 감지, stale file 정리, 삭제 안전성, rollback 정책이 추가로 필요하다. 실제 요구가 생기면 `render`와 분리된 interface로 설계한다. 현재는 source와 golden output drift를 `check`, 명시적인 설치 tree 차이를 `verify-install`, 실제 runtime discovery를 module smoke test가 담당한다.

## 개발과 검증

좁은 검증부터 실행한다.

```bash
uv run --project agent-core -m pytest agent-core/tests
uv run --project agent-core agent-core check
nix build .#agent-core
nix flake check --no-build
```

Wheel에 canonical resource가 포함되는지도 확인한다.

```bash
uv build --project agent-core --out-dir /tmp/agent-core-build
uv run --isolated \
  --with /tmp/agent-core-build/agent_core-1.0.0-py3-none-any.whl \
  agent-core check
```

Runtime module을 변경할 때는 최종 Home Manager 또는 NixOS configuration을 평가한다. 실제 `home-manager switch`, OpenClaw plugin enable, Gateway restart는 사용자 실행 단계다.

Golden hash는 intentional output 변경을 검토한 뒤에만 갱신한다. Hash 변경만으로 validation failure를 숨기지 않는다.

## 완료 조건

- 공통 rule, adapter, shared skill의 canonical source가 `agent-core/` 한 곳에 있다.
- Python renderer 하나가 manifest에서 네 runtime output을 생성한다.
- Runtime module에 독자적인 merge logic이나 shared skill 복사본이 없다.
- Pi의 system append 분리와 OpenClaw의 workspace ownership 경계가 유지된다.
- Nix package와 module은 immutable render output만 설치한다.
- Credentials, session, cache, 개인 memory가 materialized output에 포함되지 않는다.
- Python test, package resource test, Nix package, flake check가 통과한다.
