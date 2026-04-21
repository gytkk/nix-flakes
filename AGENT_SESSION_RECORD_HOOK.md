# Agent Session Record Hook 구현 계획

## 배경

여러 머신(`devsisters-macbook`, `devsisters-macstudio`, `pylv-denim`,
`pylv-sepia`, `pylv-onyx`)에서 사용한 AI 코딩 에이전트 세션 기록을 한 곳에
모아 반복 패턴 분석 및 skill 리팩토링에 활용한다.

대상은 두 가지다.

- **Claude Code**: 세션 종료 시 `SessionEnd` hook을 실행하며, hook stdin으로
  `transcript_path`를 포함한 JSON을 제공한다.
- **Codex CLI**: 이미 로컬에 세션 transcript를 저장할 수 있으며, 현재 이
  저장소의 `modules/codex/files/config.toml`은 `[history] persistence =
  "save-all"`로 설정돼 있다. 또한 공식 문서 기준으로 `hooks.json` 기반
  lifecycle hook을 지원하며, 공통 stdin payload에 `session_id`,
  `transcript_path`, `cwd`, `hook_event_name`가 포함된다. 다만 Claude와 달리
  **세션 종료 전용 이벤트는 없고**, `Stop`은 turn 단위 이벤트다.

중앙 저장 대상은 `pylv-onyx`로 하고, 별도 HTTP 업로드 서비스는 두지 않는다.
대신 이미 열려 있는 `SSH + Tailscale` 경로를 이용해 `rsync`로 transcript를
전송한다.

## 목표

- 모든 머신의 Claude Code 세션 종료 시 transcript를 `pylv-onyx`로 자동 전송
- 모든 머신의 Codex 세션 transcript도 같은 중앙 저장소로 자동 전송
- Ctrl+C / SIGTERM / 일시적 네트워크 실패에도 데이터 유실 없이 재시도
- `pylv-onyx` 다운 시에도 로컬 queue 또는 다음 기동 시 sweep으로 복구
- 업로드 hook 실패는 warning log에 요약을 남기고, worker stderr는 debug log에
  남기며, Claude 종료나 Codex continue를 막지 않음
- 새 daemon이나 포트 없이 기존 SSH 접근만 사용
- Nix flake 모듈로 관리되어 모든 환경에 일관되게 배포

## 왜 `rsync`

- 현재 `pylv-onyx`는 이미 `openssh + tailscale`이 켜져 있다.
- 새 서비스가 필요 없다.
- 작은 JSONL artifact를 안정적으로 밀어넣는 용도에는 `HTTP PUT`보다 단순하다.
- `rsync`는 증분 전송, 재시도 친화성, 기존 SSH 키 재사용 측면에서 충분히
  검증된 선택지다.

따라서 이 계획은 **`copyparty`나 별도 수신 API 없이 `rsync over SSH`**를
기본 경로로 잡는다.

또한 hook은 어디까지나 **best-effort 보조 경로**로 취급한다. transcript
업로드, queue 적재, 원격 전송, worker spawn 중 어느 단계가 실패하더라도
사용자 세션의 종료/계속 흐름은 절대 막지 않고, 로컬 warning log에는 요약만,
debug log에는 worker stderr를 남긴다.

## 비차단 구현 규약

이 문서의 wrapper와 worker는 다음 규약을 따른다.

- wrapper는 전역 `set -e` 실패 전파에 의존하지 않는다. 실패 가능 단계는 모두
  `if ! ...; then warn; success-return; fi` 형태로 개별 처리한다.
- warning / debug log 기록 자체도 best-effort다.
  `mkdir -p`, `printf >> warnings.log`, `2>> debug.log` 모두 `|| true` 또는
  `/dev/null` fallback으로 감싸고, 로그 기록 실패가 추가 실패를 만들면 안 된다.
- Claude `SessionEnd` wrapper는 어떤 내부 실패가 나도 **항상 `exit 0`** 한다.
- Codex `Stop` / `SessionStart` wrapper는 어떤 내부 실패가 나도 **항상 유효한
  성공 JSON** (`{"continue":true}`)을 stdout에 출력하고 `exit 0` 한다.
- wrapper는 worker spawn 이후 결과를 기다리지 않는다. worker, queue, SSH, rsync,
  원격 `mv` 실패는 모두 wrapper 바깥에서 흡수한다.
- queue replay를 포함한 모든 업로드 시도는 `agent + session_id` 단위 lock으로
  직렬화한다.
- 각 snapshot에는 `snapshot_mtime_ns`와 `snapshot_fingerprint`를 기록하고, 같은
  세션에 대해 **더 오래된 snapshot은 업로드하지 않는다**.

## 핵심 차이

- **Claude Code**: `transcript_path`를 `SessionEnd`에서 바로 받아 업로드하면
  된다. 세션 종료 기준이 명확하다.
- **Codex CLI**: `transcript_path` 또는 로컬 rollout file을
  `Stop`/`SessionStart`에서 다뤄야 한다. `Stop`은 turn 단위라 세션 종료 전용
  이벤트가 아니다.

Codex는 `Stop` 때마다 같은 세션 파일이 갱신될 수 있으므로, 업로드는
**append가 아니라 snapshot overwrite**로 설계해야 한다.

## 아키텍처

```text
┌─────────────────┐   SessionEnd hook   ┌──────────────────────┐
│ Claude Code     ├────────────────────►│ agent-session-upload │
└─────────────────┘                     │ wrapper              │
                                        └──────────┬───────────┘
                                                   │
┌─────────────────┐   Stop / SessionStart hook     │
│ Codex CLI       ├────────────────────────────────┘
│ (~/.codex)      │
└─────────────────┘
                                                   │
                                                   ▼
                                        ┌──────────────────────┐
                                        │ upload worker        │
                                        │ - normalize payload  │
                                        │ - dedupe/fingerprint │
                                        │ - retry queue        │
                                        └──────────┬───────────┘
                                                   │
                        ┌──────────────────────────┼─────────────────────────┐
                        │                          │                         │
                        ▼                          ▼                         ▼
                ┌──────────────┐       ┌────────────────────┐      ┌──────────────┐
                │ rsync over   │       │ local queue       │      │ onyx 로컬    │
             │ SSH          │◄──────┤ XDG state         │      │ copy          │
                │ to onyx      │       │ retry + sweep     │      └──────────────┘
                └──────────────┘       └────────────────────┘
```

## 저장 레이아웃

중앙 저장 경로는 `pylv-onyx`의 `~/agent-sessions/` 아래로 한다.

```text
~/agent-sessions/
  claude/
    <YYYY>/
      <MM>/
        <DD>/
          <session_id>.jsonl
          <session_id>.meta.json
  codex/
    <YYYY>/
      <MM>/
        <DD>/
          <session_id>.jsonl
          <session_id>.meta.json
```

실제 worker 내부에서는 명시적 절대 경로를 쓰는 편이 안전하므로, canonical
base path는 `/home/gytkk/agent-sessions`로 둔다.

`.meta.json`은 공통으로 다음 정보를 담는다.

- `agent`: `claude` 또는 `codex`
- `session_id`
- `hostname`
- `cwd`
- `hook_event_name`
- `transcript_path`
- `snapshot_mtime_ns`
- `snapshot_fingerprint`
- `uploaded_at`

에이전트별 추가 필드:

- Claude: `end_reason`, `source = "session-end"`
- Codex: `turn_id`, `stop_hook_active`, `last_assistant_message`,
  `source = "stop"` 또는 `source = "session-start-sweep"`

Codex는 같은 `session_id` 파일을 여러 번 덮어쓸 수 있다. 이는 정상 동작이며,
원격에는 항상 최신 snapshot만 남긴다.

## 구현 컴포넌트

### 1. 공통 업로드 worker

새 모듈 경로: `modules/agent-session-record/`

예상 파일:

- `modules/agent-session-record/default.nix`
- `modules/agent-session-record/files/agent-session-upload-worker.sh`
- `modules/agent-session-record/files/claude-session-upload.sh`
- `modules/agent-session-record/files/codex-stop-upload.sh`
- `modules/agent-session-record/files/codex-session-start-sweep.sh`

배포 경로:

- `~/.local/bin/agent-session-upload-worker`
- `~/.local/bin/claude-session-upload`
- `~/.local/bin/codex-stop-upload`
- `~/.local/bin/codex-session-start-sweep`

**책임**:

- stdin JSON 또는 임시 payload 파일을 읽어 agent-neutral 형태로 정규화
- `session_id`, `transcript_path`, `cwd`, `hook_event_name` 추출
- hostname 파악 (`hostname -s`)
- 원격 상대 경로 계산:
  `agent/<YYYY>/<MM>/<DD>/<session_id>.(jsonl|meta.json)`
- 실패/skip 사유 요약을
  `${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-record/warnings.log`
  에 append
- worker stderr를
  `${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-record/debug.log`
  에 append
- 업로드 실패 시
  `${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-record/` 아래 queue에 적재
- `agent + session_id` 단위 `flock`으로 업로드 경합 직렬화
- queue item과 state file에 `snapshot_mtime_ns`, `snapshot_fingerprint`를 저장
- 같은 세션의 최신 known snapshot보다 오래된 queue item은 replay skip
- Codex는 같은 세션이 여러 번 `Stop`될 수 있으므로, 마지막 업로드한
  fingerprint를 저장해 동일 snapshot이면 skip
- Codex `transcript_path`가 `null`이면 fallback으로
  `~/.codex/sessions/**/rollout-*-${session_id}.jsonl`를 탐색

Codex의 경우 로컬 실측상 transcript는 다음 패턴으로 저장된다.

```text
~/.codex/sessions/YYYY/MM/DD/rollout-<timestamp>-<session_id>.jsonl
```

`history.jsonl`은 prompt index로는 유용하지만 중앙 저장의 canonical artifact로는
너무 축약돼 있으므로, 1차 대상은 rollout transcript JSONL로 잡는다.

### 2. 원격 전송 방식

기본 전송 방식은 다음 순서로 한다.

1. `ssh gytkk@pylv-onyx "mkdir -p ..."` 로 원격 디렉터리 생성
2. `rsync`로 원격 임시 파일(`*.{fingerprint}.tmp`)에 전송
3. `ssh`로 `mv` 하여 최종 경로로 원자적 치환

이 방식의 장점:

- 수신 측에 새 서비스가 필요 없다
- 전송 중 중간 파일이 최종 경로에 노출되지 않는다
- Codex snapshot overwrite를 안전하게 구현할 수 있다
- 같은 세션 lock과 freshness check를 함께 쓰면 stale retry 역전 위험을 줄일 수
  있다

예시 흐름:

```bash
ssh gytkk@pylv-onyx "mkdir -p /home/gytkk/agent-sessions/claude/$yyyy/$mm/$dd"
rsync -az "$local_file" \
  "gytkk@pylv-onyx:/home/gytkk/agent-sessions/claude/$yyyy/$mm/$dd/$name.$fingerprint.tmp"
ssh gytkk@pylv-onyx \
  "mv /home/gytkk/agent-sessions/claude/$yyyy/$mm/$dd/$name.$fingerprint.tmp \
      /home/gytkk/agent-sessions/claude/$yyyy/$mm/$dd/$name"
```

`pylv-onyx` 자체에서 실행 중이면 SSH round-trip 없이 로컬 copy로 단축한다.

### 3. Claude wrapper

경로:

- `modules/agent-session-record/files/claude-session-upload.sh`

**역할**:

- Claude `SessionEnd` stdin payload를 그대로 읽음
- worker를 백그라운드 detach
- hook latency를 최소화하고 즉시 종료
- worker spawn 또는 사전 검증이 실패해도 warning log에만 요약을 남기고 exit `0`

**의사코드**:

```bash
#!/usr/bin/env bash
set -u

warn_log="${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-record/warnings.log"
debug_log="${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-record/debug.log"

warn() {
  mkdir -p "${warn_log%/*}" 2>/dev/null || true
  printf '%s claude-session-upload: %s\n' \
    "$(date -Is)" "$*" >>"$warn_log" 2>/dev/null || true
}

payload_file=""
if ! payload_file="$(mktemp "${TMPDIR:-/tmp}/claude-session-upload.XXXXXX")"; then
  warn "mktemp failed"
  exit 0
fi

if ! cat >"$payload_file"; then
  warn "failed to persist SessionEnd payload"
  rm -f "$payload_file" 2>/dev/null || true
  exit 0
fi

stderr_sink="/dev/null"
if mkdir -p "${debug_log%/*}" 2>/dev/null && : >>"$debug_log" 2>/dev/null; then
  stderr_sink="$debug_log"
fi

if ! nohup "$HOME/.local/bin/agent-session-upload-worker" \
  --agent claude \
  --payload-file "$payload_file" \
  >/dev/null 2>>"$stderr_sink" & then
  warn "failed to spawn upload worker"
  rm -f "$payload_file" 2>/dev/null || true
  exit 0
fi

disown || true
exit 0
```

### 4. Codex wrapper

경로:

- `modules/agent-session-record/files/codex-stop-upload.sh`
- `modules/agent-session-record/files/codex-session-start-sweep.sh`

Codex는 공식 문서 기준으로 `Stop` hook이 plain text stdout을 허용하지 않고,
exit `0`일 때 JSON을 기대한다. 따라서 Claude wrapper와 달리 background
worker를 띄운 뒤에도 **반드시 유효한 JSON을 stdout에 출력**해야 한다.

또한 `Stop`은 turn 단위이므로, 비정상 종료 직전 마지막 변경분이 누락될 수
있다. 이를 보완하기 위해 `SessionStart`에서 stale transcript sweep을 같이
실행한다.

**Stop wrapper 의사코드**:

```bash
#!/usr/bin/env bash
set -u

warn_log="${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-record/warnings.log"

warn() {
  mkdir -p "${warn_log%/*}" 2>/dev/null || true
  printf '%s codex-stop-upload: %s\n' \
    "$(date -Is)" "$*" >>"$warn_log" 2>/dev/null || true
}

continue_json() {
  printf '{"continue":true}\n'
}

payload_file=""
if ! payload_file="$(mktemp "${TMPDIR:-/tmp}/codex-stop-upload.XXXXXX")"; then
  warn "mktemp failed"
  continue_json
  exit 0
fi

if ! cat >"$payload_file"; then
  warn "failed to persist Stop payload"
  rm -f "$payload_file" 2>/dev/null || true
  continue_json
  exit 0
fi

if ! nohup "$HOME/.local/bin/agent-session-upload-worker" \
  --agent codex \
  --payload-file "$payload_file" \
  >/dev/null 2>&1 & then
  warn "failed to spawn upload worker"
  rm -f "$payload_file" 2>/dev/null || true
  continue_json
  exit 0
fi

disown || true

continue_json
exit 0
```

**SessionStart sweep wrapper 역할**:

- queue 재시도
- 이전 실행에서 업로드 못한 Codex rollout 탐색
- 마지막 업로드 fingerprint와 비교해 stale transcript를 보정 업로드
- stdout에는 Codex hook 규격에 맞는 성공 JSON만 반환
- worker spawn 또는 sweep 초기화 실패 시에도 warning log에는 요약만 남기고
  `{"continue":true}` 유지

### 5. Hook 등록

#### Claude Code

각 환경의 `~/.claude/settings.json`에 `SessionEnd` hook 추가:

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "~/.local/bin/claude-session-upload"
          }
        ]
      }
    ]
  }
}
```

→ 이 저장소에서는 `modules/claude/files/settings.json`가 canonical JSON이므로,
해당 파일의 `"hooks"` 객체를 직접 갱신한다

#### Codex CLI

`~/.codex/hooks.json`을 추가하고, `config.toml`에서 feature flag를 활성화:

```toml
[features]
codex_hooks = true
```

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "~/.local/bin/codex-session-start-sweep",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.local/bin/codex-stop-upload",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

→ `modules/codex/default.nix`에서 `~/.codex/hooks.json`을 배포하고,
지속 설정인 `/etc/codex/managed_config.toml`의 소스인
`modules/codex/files/config.toml`에 `features.codex_hooks = true`를 둔다.
`~/.codex/config.toml`은 activation 시 `[projects]` 보존용으로 재작성되므로,
hook feature flag를 여기에 두지 않는다.

### 6. Nix 모듈 확장

Claude 전용 option 대신 공통 모듈로 승격:

```nix
options.modules.agentSessionRecord = {
  enable = lib.mkEnableOption "Central agent session transcript upload";
  remoteHost = lib.mkOption {
    type = lib.types.str;
    default = "pylv-onyx";
    description = "SSH host receiving agent session uploads";
  };
  remoteUser = lib.mkOption {
    type = lib.types.str;
    default = "gytkk";
    description = "SSH user for central agent session uploads";
  };
  remoteBasePath = lib.mkOption {
    type = lib.types.str;
    default = "/home/gytkk/agent-sessions";
    description = "Remote base path for agent session uploads";
  };
  localShortCircuitHost = lib.mkOption {
    type = lib.types.str;
    default = "pylv-onyx";
    description = "Host name that should use local copy instead of SSH";
  };
  agents = {
    claude.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    codex.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };
};
```

각 모듈의 역할:

- `modules/agent-session-record/default.nix`
  - 공통 script 배포
  - queue/state 디렉터리 준비
  - 공통 option 정의
  - `rsync`, `openssh`, `flock`, `jq` 의존성 보장
- `modules/claude/default.nix`
  - `modules/claude/files/settings.json`의 canonical `"hooks"` JSON을 직접 관리
- `modules/codex/default.nix`
  - `hooks.json` 배포
  - `/etc/codex/managed_config.toml` source를 통해
    `features.codex_hooks = true` 활성화
  - 현재 `history.persistence = "save-all"` 유지

`pylv-onyx`에서는 local short-circuit가 켜져, `/home/gytkk/agent-sessions`로
직접 copy 하도록 한다.

### 7. 수신 측 준비

`pylv-onyx`에는 새 서비스가 필요 없다. 필요한 것은 다음뿐이다.

- `gytkk` 계정의 home 아래에 `/home/gytkk/agent-sessions`
- 하위 디렉터리 `claude`, `codex`
- SSH로 write 가능한 권한

준비 방식 후보:

- Home Manager activation에서 디렉터리 생성
- user-level systemd tmpfiles
- 최초 전송 시 worker가 `mkdir -p` 수행

**1차 구현은 worker가 `mkdir -p`를 보장하는 것으로 충분**하다.

## 인증과 접근 제어

별도 업로드 토큰은 쓰지 않는다. 기존 SSH 인증을 그대로 사용한다.

- 전송 경로: Tailscale 내부망
- 인증 수단: 기존 SSH 키 / ssh-agent
- 접근 제어: `gytkk@pylv-onyx` 계정 권한

주의점:

- 비대화형 hook에서도 SSH가 동작해야 하므로, 기존 로그인 세션이 가진 키 접근이
  끊기지 않는지 확인 필요
- 키 프롬프트가 뜨면 hook이 지연되므로, 무인증 실행 가능한 SSH 상태를 전제로
  해야 한다

## 엣지 케이스

- **onyx 자체에서 실행**: SSH 대신 로컬 `cp` 또는 `install` 사용
- **네트워크 오프라인**: queue 디렉터리에 적재, 다음 hook에서 재시도
- **Claude transcript 파일 미존재 / 0 byte**: 업로드 skip, 경고 로그
- **SessionEnd / Stop hook 내부 실패**: warning log에는 요약만 남기고, worker
  stderr는 debug log에 append하며, Claude 종료 / Codex continue는 그대로 진행
- **Codex `transcript_path = null`**: 세션 디렉터리 fallback 탐색
- **Codex `Stop` 반복 호출**: 동일 `session_id` snapshot overwrite, fingerprint
  동일 시 skip
- **stale retry 역전**: `agent + session_id` lock과 `snapshot_mtime_ns` 비교로
  더 오래된 queue item replay skip
- **Codex 비정상 종료**: 마지막 `Stop`가 실행되지 않아도 다음 `SessionStart`
  sweep에서 stale rollout 업로드
- **원격 파일 부분 업로드**: `.tmp`로 전송 후 `mv`하여 최종 파일 교체
- **Hook이 너무 오래 걸림**: wrapper는 반드시 detach, worker 자체 timeout 적용
- **동시 세션 종료 / 동시 turn stop**: queue 재시도는 `flock`으로 직렬화
- **민감 정보 유출 우려**: transcript에 secret이 포함될 수 있음. 내부망 전송을
  기본으로 하고, 추후 redaction 필터 도입 검토
- **Codex hook continuation 루프**: 업로드 hook은 절대 `decision = "block"`을
  반환하지 않고, 항상 정상 continue만 반환

## 테스트 계획

1. **Claude unit**: 고정 `SessionEnd` payload로 transcript 경로와 meta 계산 확인
2. **Codex unit**: 고정 `Stop` payload로 wrapper가 즉시
   `{"continue":true}`를 출력하는지 확인
3. **Claude failure unit**: worker spawn 실패를 주입해도 wrapper가 exit `0`이고
   warning log만 남기는지 확인
4. **Codex failure unit**: worker spawn 실패를 주입해도 wrapper가
   `{"continue":true}`를 반환하고 exit `0`인지 확인
5. **Codex fallback unit**: `transcript_path = null`일 때
   `~/.codex/sessions/**/rollout-*-${session_id}.jsonl` 탐색이 맞는지 확인
6. **stale queue unit**: 오래된 `snapshot_mtime_ns`를 가진 queue item이 최신
   snapshot 뒤에 replay되어도 skip 되는지 확인
7. **로컬 통합**: `pylv-onyx`에서 local short-circuit로
   `/home/gytkk/agent-sessions/{claude,codex}/YYYY/MM/DD` 생성 및 파일 도착 확인
8. **원격 Claude 통합**: `pylv-denim`에서 Claude 세션 종료 후 onyx 도착 확인
9. **원격 Codex 통합**: `pylv-denim`에서 Codex 대화 2턴 진행 후 같은
   `session_id`가 최신 snapshot으로 덮어써지는지 확인
10. **Codex 재기동 복구**: 업로드 실패 상태를 만든 뒤 Codex 재시작 시
   `SessionStart` sweep이 queue/stale transcript를 비우는지 확인
11. **오프라인 재시도**: onyx 중단 상태에서 transcript 생성 후 queue 적재 확인,
   복구 뒤 다음 hook에서 업로드되는지 확인
12. **비정상 종료**: Claude는 Ctrl+C / SIGTERM, Codex는 강제 종료 후 다음
   `SessionStart`에서 복구되는지 확인
13. **hook 지연**: 세션 종료 체감 시간이 늘어나지 않는지 확인

## 롤아웃 순서

1. `modules/agent-session-record/` 공통 worker 및 wrapper 작성
2. `modules/claude/default.nix`에 `SessionEnd` hook 연결
3. `modules/codex/default.nix`에 `hooks.json` 및 `codex_hooks` 활성화 추가
4. `pylv-onyx`에서 local short-circuit와 저장 디렉터리 경로 검증
5. `pylv-denim`에서 Claude + Codex 둘 다 엔드-투-엔드 검증
6. 나머지 환경(`devsisters-*`, `pylv-sepia`)으로 확장

## 후속 작업

- 모인 transcript를 주기적으로 파싱하여 반복 패턴 추출
- Claude/Codex transcript 공통 분석 파이프라인 구축
- skill-creator와 연계하여 반복 패턴을 skill 초안으로 생성
- 민감 정보 redaction 필터
- 분석용 로컬 검색 CLI (`agent-sessions grep <pattern>`)

## 미확정 / 확인 필요

- Claude `SessionEnd`의 실제 종료 사유 필드명 (`reason`, `end_reason` 등)
- Codex `Stop` payload에서 현재 빌드의 `transcript_path`가 항상 채워지는지
- Codex `SessionStart` hook에서 stale transcript sweep만으로 충분한지
- `pylv-onyx`에서 `agent-sessions` 디렉터리를 Home Manager activation으로
  만들지, worker가 매번 `mkdir -p` 하게 둘지
- 비대화형 hook 환경에서도 SSH 키 접근이 항상 보장되는지
- macOS에서 `hostname -s`가 중앙 저장 경로 키로 충분히 안정적인지
