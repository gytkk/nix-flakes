# Hermes agent session record 연동 계획

## 목표

Hermes Agent가 Discord, cron, CLI에서 처리한 대화와 그 과정에서 변경된 memory 및 skill을 기존 `agent-session-record` 저장 체계에 안전하게 기록한다. Claude Code와 Codex의 현재 기록 동작은 유지하고, Hermes의 실행 방식이나 사용자 설정 파일을 이 저장소가 덮어쓰지 않는다.

Hermes는 외부 요청을 실행하는 gateway이자 원본 세션의 소유자로 유지한다. `agent-session-record`는 원본을 읽어 정규화하고 보관하는 시스템이며, `agent-prompts`는 검토를 거친 규칙과 skill의 source of truth로 유지한다.

## 범위

이번 계획은 다음 결과를 포함한다.

- Hermes 세션을 공식 export 명령으로 추출하고 기존 redaction, queue, upload 흐름에 연결한다.
- Hermes memory와 로컬 mutable skill의 변경 이력을 세션 기록과 분리된 content-addressed artifact로 보관한다.
- 공용 운영 규칙과 portable skill을 Hermes에서도 사용할 수 있게 한다.
- 기록에서 공용 memory, skill, prompt 후보를 만들되 자동으로 적용하지 않는다.
- Discord 사용자 ID와 channel ID 같은 routing 정보는 원문으로 manifest에 저장하지 않는다.

다음 항목은 이번 범위에 포함하지 않는다.

- Hermes JSONL을 Claude Code나 Codex의 내부 세션 형식으로 변환하는 작업
- 기록된 memory나 skill을 검토 없이 공용 설정으로 자동 승격하는 작업
- 사용자 `SOUL.md`, Hermes 설정, 기존 memory 또는 local skill을 Home Manager가 소유하거나 덮어쓰는 작업
- `gytkk-space`에 있는 session mining 자동화의 구현. 이 저장소에서는 입력 계약과 후속 작업만 정의한다.

## 확인된 현재 구조

- `modules/agent-session-record/`는 Claude Code와 Codex만 provider로 허용한다.
- upload worker의 queue 이름, manifest 검증, uploader 선택도 `claude|codex`에 고정되어 있다.
- 세션은 redaction 이후 `/home/gytkk/agent-sessions/<scope>/<provider>/<YYYY>/<MM>/<DD>/`에 transcript와 manifest로 저장된다.
- `modules/hermes-agent/`에는 현재 설명 문서만 있고 Home Manager module은 없다.
- Hermes gateway의 사용자 서비스 PATH 설정은 `base/pylv/onyx.nix`에 있다.
- `modules/agent-prompts/lib.nix`가 조합하는 공용 지침 전체는 약 12 KB이다. Hermes plugin prompt section의 전체 한도인 8,000자를 넘으므로 그대로 삽입할 수 없다.

## 근거가 되는 Hermes 동작

- Hermes는 `~/.hermes/state.db`에 세션과 message를 보관한다. 공식 `hermes sessions export <path> --session-id <id> --redact` 명령은 세션별 metadata와 message를 JSONL로 내보낸다. [Sessions 문서](https://hermes-agent.nousresearch.com/docs/user-guide/sessions/)
- `on_session_end` hook은 실패를 포함해 각 `run_conversation` turn이 끝날 때 실행되고, `on_session_finalize`는 활성 세션을 정리할 때 실행된다. `post_tool_call`은 memory 및 skill 관리 도구의 성공 여부를 확인하는 데 사용할 수 있다. [Hooks 문서](https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks)
- Hermes plugin은 `plugin.yaml`과 `register(ctx)`를 구현하는 Python module로 구성되며 Hermes process 안에서 실행된다. [Plugins 문서](https://hermes-agent.nousresearch.com/docs/developer-guide/plugins)
- Hermes는 프로젝트의 `AGENTS.md`를 root부터 현재 directory까지 읽는다. Plugin이 추가하는 system prompt section은 section당 4,000자, 전체 8,000자로 제한되며 세션 시작 또는 resume 시 고정된다. [Context files 문서](https://hermes-agent.nousresearch.com/docs/user-guide/features/context-files/), [Hooks 문서](https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks)

## 설계

### 책임 분리

```text
Discord, cron, CLI
        |
        v
Hermes gateway and sessions
        |
        | on_session_end / on_session_finalize
        v
Hermes recorder plugin
        |
        | small non-blocking event
        v
agent-session-record
        |
        +--> redacted session archive
        +--> redacted knowledge artifacts
        +--> reviewed derivation candidates
                         |
                         v
              agent-prompts / shared skills
```

Hermes plugin은 세션 DB를 직접 읽거나 원문을 upload하지 않는다. Hook payload에서 안정적인 식별 정보만 recorder에 전달하고 즉시 반환한다. Recorder가 별도 process에서 공식 export 명령을 실행하고, redaction과 queue 처리를 담당한다.

### Provider interface

Claude Code와 Codex의 현재 조건문에 Hermes 분기를 추가하는 방식 대신 provider별 capture adapter를 둔다.

```python
class ProviderAdapter(Protocol):
    def hook_contract(self, event: str) -> HookContract: ...
    def captures_from_event(
        self, payload: Mapping[str, object], context: CaptureContext
    ) -> list[CaptureSource]: ...
    def discover_captures(self, context: CaptureContext) -> list[CaptureSource]: ...
```

Adapter는 provider 고유의 hook payload, 세션 위치, export 명령만 해석한다. 공통 recorder는 run ID, redaction, deduplication, queue, retry, upload, manifest 생성을 소유한다. 기존 Claude Code와 Codex 동작을 먼저 이 interface로 옮긴 뒤 Hermes adapter를 추가한다.

### Session capture

1. Hermes plugin이 `on_session_end`에서 세션 ID와 event type을 recorder에 전달한다.
2. Recorder가 argument array로 `hermes sessions export`를 실행한다. Shell 문자열은 사용하지 않는다.
3. Export 결과를 기존 session redaction pipeline에 통과시킨다.
4. Provider를 `hermes`로 지정하고 기존 queue와 manifest schema를 확장해 저장한다.
5. 같은 session과 turn에 대한 hook이 반복되어도 content hash와 event identity로 중복 저장하지 않는다.
6. `on_session_finalize`에서는 누락된 마지막 turn이 있는지 재조정한다.

Hermes manifest에는 다음 optional metadata만 추가한다.

- `platform`: `discord`, `cron`, `cli`와 같은 실행 표면
- `profile`: Hermes profile 이름
- `routing_key_hash`: 사용자, channel, cron target을 구분하기 위한 keyed hash
- `system_prompt_fingerprint`: 세션에 고정된 prompt의 hash
- `compression_count`: context compression 횟수
- `parent_session_id_hash`: subagent 또는 parent session 연결용 hash

Raw Discord user ID, guild ID, channel ID, username은 manifest에 넣지 않는다. Export transcript에 포함된 값은 일반 secret 및 PII redaction 규칙을 적용한다.

### Memory와 skill 기록

세션 transcript와 knowledge artifact는 수명과 deduplication 방식이 다르므로 별도 namespace에 저장한다.

```text
agent-sessions/personal/hermes/knowledge/
  blobs/<sha256>.jsonl
  events/<YYYY>/<MM>/<DD>/<event_id>.json
```

- `blobs/`는 redaction을 마친 immutable content를 hash로 저장한다.
- `events/`는 어느 session과 tool call이 artifact를 만들거나 참조했는지 기록한다.
- 동일한 content는 blob을 한 번만 저장하고 event만 추가한다.
- 첫 구현에서는 `~/.hermes/memories/MEMORY.md`와 `~/.hermes/memories/USER.md`를 memory source로 취급한다.
- Skill은 `hermes-local`, `repo-managed`, `bundled`, `external-tap`으로 분류한다.
- `hermes-local` mutable skill만 본문을 기록한다. Repo-managed skill은 repository, revision, path, hash를 기록하고 원문을 복제하지 않는다.
- Symlink는 따라가지 않는다. Binary와 크기 제한을 넘은 asset은 path, size, hash, 제외 사유만 기록한다.

각 knowledge event에는 다음 필드를 둔다.

- artifact type과 source class
- redacted content hash
- linked provider, session, run
- capture time과 source path의 안전한 상대 경로
- redaction status와 character count
- `eligible_for_derivation`

Memory 또는 `skill_manage` tool call이 성공하면 `post_tool_call` hook으로 관련 파일의 fingerprint를 다시 계산한다. Hook을 거치지 않은 수동 변경을 찾기 위해 하루 한 번 full fingerprint reconciliation도 실행한다.

### Prompt와 shared skill 제공

- 프로젝트 `AGENTS.md`는 Hermes의 기존 context file discovery를 사용한다.
- Global 공용 지침은 전체 문서를 복사하지 않는다. Hermes plugin prompt section에는 운영 및 보안 규칙의 짧은 핵심만 생성한다.
- 생성 결과는 section당 4,000자와 전체 8,000자 제한을 자동 검사한다.
- 사용자 `SOUL.md`는 변경하지 않는다.
- `modules/agent-prompts/skills.nix`의 portable shared skill만 Hermes가 읽는 skill directory에 read-only로 노출한다.
- Hermes local mutable skill directory는 공용 skill directory와 분리한다.
- 이름이 충돌하면 기존 local skill을 우선하고 경고를 남긴다. 공용 skill을 조용히 덮어쓰거나 반대로 local skill을 가리지 않는다.

### Derivation과 승격

기록은 곧바로 prompt나 memory가 되지 않는다. Mining 단계는 다음 candidate만 생성한다.

- 반복되는 사용자 선호: memory candidate
- 여러 세션에서 반복되는 작업 절차: skill candidate
- 모든 repository와 agent에 적용할 규칙: `agent-prompts` candidate
- 이 repository에만 적용할 규칙: root `AGENTS.md` candidate

Candidate에는 provider, run, artifact hash, 선정 이유, 검토 상태, 적용 commit을 기록한다. 사람이 검토해 적용하기 전에는 어떤 agent 설정도 변경하지 않는다.

### 실패와 보안 정책

- Hermes export 실패는 원문 DB를 직접 읽는 fallback으로 이어지지 않는다. 재시도 가능한 local queue item과 진단 정보만 남긴다.
- Hook과 recorder 호출 실패는 Hermes의 사용자 응답을 실패시키지 않는다.
- Knowledge artifact redaction이 실패하면 remote archive에 원문을 올리지 않고 local quarantine에 둔다.
- 현재 session recorder는 일부 redaction 실패 경로에서 원문을 archive할 수 있다. 모든 provider에 대해 `redaction failure -> local quarantine, no remote upload`로 바꾸는 것을 권장한다.
- 위 공통 redaction 정책 변경은 security control의 변경이므로 구현 전에 사용자의 명시적 승인을 받는다. 승인을 받기 전에는 Hermes knowledge artifact에만 fail-closed 동작을 적용한다.
- Plugin은 Hermes process 안에서 실행되므로 최소 권한 동작만 구현하고, shell command, arbitrary path, network upload를 허용하지 않는다.

## 구현 단계

### 0. Onyx에서 runtime fixture 확보

- [ ] 설치된 Hermes version과 `hermes sessions export --help` 결과를 기록한다.
- [ ] 개인 정보가 없는 임시 CLI session을 만들고 `--redact` JSONL fixture를 확보한다.
- [ ] `on_session_end`, `on_session_finalize`, `post_tool_call` callback의 실제 keyword argument를 debug plugin으로 기록한다.
- [ ] Discord, cron, CLI가 동일한 session identity를 어떻게 표현하는지 확인한다.
- [ ] `state.db`나 실제 Discord 대화 원문은 fixture에 포함하지 않는다.

완료 기준: fixture만으로 Hermes adapter와 hook parser의 unit test를 작성할 수 있고, 문서와 다른 version-specific field가 목록화되어 있다.

### 1. Provider seam 정리

수정할 파일:

- `modules/agent-session-record/files/agent_session_provider.py`
- `modules/agent-session-record/files/agent_session_record.py`
- `modules/agent-session-record/files/agent_session_upload_worker.py`
- `modules/agent-session-record/tests/test_agent_session_record.py`

작업:

- [ ] Claude Code와 Codex를 `ProviderAdapter` 구현으로 옮긴다.
- [ ] Provider registry가 queue pattern, manifest validation, discovery, upload dispatch의 단일 source of truth가 되게 한다.
- [ ] Provider별 capture가 공통 `CaptureSource`로 정규화되는지 검사한다.
- [ ] 기존 manifest schema와 저장 경로를 바꾸지 않는다.
- [ ] 기존 test fixture로 byte-level 또는 semantic 동등성을 확인한다.

완료 기준: Claude Code와 Codex의 기존 test가 모두 통과하며, recorder와 worker에 provider 이름을 직접 비교하는 분기가 남지 않는다.

권장 commit: `refactor(agent-session-record): deepen provider capture interface`

### 2. Hermes session capture 추가

수정하거나 생성할 파일:

- `modules/agent-session-record/default.nix`
- `modules/agent-session-record/files/agent_session_provider.py`
- `modules/agent-session-record/files/agent_session_record.py`
- `modules/agent-session-record/files/agent_session_upload_worker.py`
- `modules/agent-session-record/tests/test_agent_session_record.py`
- `modules/hermes-agent/default.nix`
- `modules/hermes-agent/files/plugins/agent-session-record/plugin.yaml`
- `modules/hermes-agent/files/plugins/agent-session-record/__init__.py`
- `base/default.nix`
- `base/pylv/onyx.nix`

작업:

- [ ] `hermes` provider와 manifest optional metadata를 registry에 추가한다.
- [ ] Fixture를 사용해 official export adapter를 구현한다.
- [ ] Hermes plugin이 non-blocking recorder event만 보내게 한다.
- [ ] Plugin 설치와 enable 상태를 Home Manager module로 관리하되 사용자 Hermes config는 덮어쓰지 않는다.
- [ ] Provider enable option과 service environment를 기존 module pattern에 맞게 연결한다.
- [ ] 같은 event 재전송, export 실패, queue retry를 test한다.
- [ ] Raw routing ID가 manifest에 들어가지 않는지 test한다.

완료 기준: 임시 Hermes session 한 건이 redaction된 transcript와 valid manifest로 `personal/hermes` 아래에 한 번만 저장되고, recorder가 중단되어도 Hermes 응답은 정상 완료된다.

권장 commit: `feat(agent-session-record): capture Hermes sessions`

### 3. Hermes knowledge artifact 추가

수정할 파일:

- `modules/agent-session-record/files/agent_session_provider.py`
- `modules/agent-session-record/files/agent_session_record.py`
- `modules/agent-session-record/files/agent_session_upload_worker.py`
- `modules/agent-session-record/tests/test_agent_session_record.py`
- `modules/hermes-agent/files/plugins/agent-session-record/__init__.py`

작업:

- [ ] Memory와 skill fingerprint, blob, event schema를 정의한다.
- [ ] `post_tool_call` 성공 event와 daily reconciliation을 연결한다.
- [ ] Blob deduplication과 event linkage를 구현한다.
- [ ] Symlink traversal, binary, oversized asset, path escape를 거부한다.
- [ ] Redaction 성공 전에는 remote queue에 artifact를 넣지 않는다.
- [ ] 공통 fail-closed 변경을 적용한다면 먼저 별도 승인과 regression test를 추가한다.

완료 기준: 같은 memory를 여러 번 읽어도 blob은 한 개만 생기고 event는 session별로 연결된다. Redaction 실패, symlink, binary asset의 원문은 remote queue에 들어가지 않는다.

권장 commit: `feat(agent-session-record): archive Hermes knowledge artifacts`

### 4. 공용 prompt와 portable skill 연결

수정하거나 생성할 파일:

- `modules/hermes-agent/default.nix`
- `modules/hermes-agent/files/shared-system-prompt.md`
- 필요한 경우 `modules/agent-prompts/lib.nix`
- 필요한 경우 `modules/agent-prompts/skills.nix`
- `README.md`

작업:

- [ ] 공용 운영 및 보안 규칙에서 Hermes용 짧은 prompt section을 생성한다.
- [ ] 생성 결과의 길이 제한과 stable hash를 test한다.
- [ ] Portable shared skill을 Hermes skill directory에 read-only로 노출한다.
- [ ] Local skill과의 이름 충돌을 검사하고 local 우선 경고를 구현한다.
- [ ] `SOUL.md`, memory, local skill을 module activation이 수정하지 않는지 확인한다.
- [ ] README에 소유권, 생성 경로, update 방법을 설명한다.

완료 기준: 새 Hermes session이 공용 핵심 규칙과 portable skill 목록을 인식하고, 사용자 소유 파일의 hash와 내용은 activation 전후에 바뀌지 않는다.

권장 commit: `feat(hermes-agent): share prompts and portable skills`

### 5. Mining 입력 계약 정의

이 단계의 실제 consumer 구현은 `gytkk-space`에서 진행한다.

- [ ] Session manifest와 knowledge event를 읽는 versioned input schema를 문서화한다.
- [ ] Candidate provenance와 review status schema를 정의한다.
- [ ] `mine-sessions.sh`가 Hermes를 선택적으로 포함할 수 있게 별도 작업을 등록한다.
- [ ] 자동 승격이 없고 commit이 명시된 candidate만 적용된다는 invariant를 test한다.

완료 기준: 이 저장소의 fixture로 consumer contract test를 실행할 수 있고, Hermes 기록을 제외하거나 포함하는 동작이 명시적 option으로 구분된다.

권장 commit: `feat(agent-prompts): define Hermes mining candidates`

## 검증 계획

### 자동 검증

- Python test는 `uv run`으로 실행한다.
- 수정한 Nix 파일은 모두 `nixfmt`로 format한다.
- Provider registry와 Home Manager wiring처럼 evaluation에 민감한 변경이 있을 때 targeted `nix eval`을 먼저 실행한다.
- 전체 module 연결을 바꾼 단계에서는 `nix flake check --no-build`를 실행한다.
- `git diff --check`와 최종 diff 검토로 whitespace 오류와 범위 밖 변경을 확인한다.

필수 test case:

- Claude Code와 Codex regression
- Hermes CLI를 대체하는 fake executable과 안전한 argv 전달
- 성공, 실패, 중복, retry hook event
- Secret, PII, Discord routing identifier redaction
- Redaction 실패 시 remote upload 차단
- Symlink traversal과 repository 또는 Nix store 원문 복제 차단
- Binary 및 크기 제한 asset 제외
- Provider disabled 상태의 no-op
- Memory blob deduplication과 event provenance
- Prompt section 길이 제한과 skill name collision

### Onyx smoke test

`home-manager switch`는 사용자가 실행한다.

1. `hermes plugins list`에서 recorder plugin enable 상태를 확인한다.
2. Plugin 및 hook 상태 명령이나 service log에서 callback 등록을 확인한다.
3. 개인 정보가 없는 Discord DM 한 건, cron 또는 CLI session 한 건을 실행한다.
4. 각 session의 redacted transcript, manifest, knowledge event를 확인한다.
5. Raw token, secret, Discord user ID, channel ID가 archive와 manifest에 없는지 확인한다.
6. Recorder를 일시적으로 실패시켜도 Hermes 응답이 완료되고 local queue retry가 동작하는지 확인한다.

## Rollout

1. Session capture만 enable하고 1주 동안 archive 중복, 누락, redaction 결과를 확인한다.
2. Knowledge capture를 enable하되 mining은 read-only report만 생성한다.
3. Prompt와 portable skill 연결은 archive 안정성을 확인한 뒤 enable한다.
4. Candidate 승격은 계속 수동 review와 local commit으로만 수행한다.
5. 각 단계는 별도 commit과 enable option으로 되돌릴 수 있게 유지한다.

## 승인과 남은 결정

구현 전에 다음 두 항목을 확정한다.

1. 모든 provider의 redaction 실패를 local quarantine으로 통일할지 승인받는다. 권장안은 모든 provider에서 remote upload를 fail-closed로 처리하는 것이다.
2. Onyx의 실제 Hermes version과 hook/export fixture를 확보해 문서에 없는 field 차이를 확인한다.

그 외 설계는 다음 기본값으로 진행한다.

- Hermes는 외부 요청 runtime과 canonical session store로 유지한다.
- `agent-session-record`는 read-only archive이며 Hermes DB를 수정하지 않는다.
- 공용 prompt와 skill의 변경은 `agent-prompts`에서 검토하고 commit한다.
- Discord routing identity는 keyed hash만 저장한다.
- Session, memory, skill은 서로 다른 record type으로 저장한다.
