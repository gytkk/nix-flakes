# Pi Performance Audit and Recommended Actions

현재 저장소가 관리하는 Pi 설정, 글로벌 지침, 스킬, 확장, 패키지와 실제
세션 메타데이터를 기준으로 수행한 성능 감사 결과다.

- **Date:** 2026-08-08
- **Pi version:** 0.84.1
- **Default runtime:** `openai-codex/gpt-5.6-sol`, thinking `high`
- **Scope:** `modules/pi/`, `~/.pi/agent/`의 실제 로드 상태, 설치된 Pi 패키지,
  현재 저장소의 상위 레벨 세션
- **Status:** Web Access의 `workflow: "none"`과 전역 agent rule 통합을
  적용했다. 나머지 action item은 아직 적용하지 않았다.

## Executive summary

현재 체감 지연은 Pi 프로세스 시작 자체보다 다음 두 항목의 영향을 더 크게
받을 가능성이 높다.

1. 기본 모델이 항상 `gpt-5.6-sol` + `high`로 실행된다.
2. 매 모델 요청에 15개 활성 도구와 약 42K자의 도구 메타데이터가 노출된다.

특히 `subagent` 도구 하나가 약 18K자이고, subagent 관련 도구 전체가 활성
도구 메타데이터의 약 51%를 차지한다. 글로벌 및 저장소 지침도 약 19K자였다.
감사 이후 범용 코딩 원칙은 `modules/agent-rules/AGENTS.md`로 통합하고, 별도
코딩 방법론 스킬을 읽는 라운드는 제거했다.

확장 전체의 warm startup 비용은 약 0.44초였다. 무시할 수는 없지만 모델 호출
한 번이 수 초에서 수십 초 걸리는 것과 비교하면 우선순위가 낮다.

가장 효과가 클 것으로 예상되는 순서는 다음과 같다.

1. 일상 작업의 기본 모델을 Terra/medium으로 낮추고 Sol/high는 선택적으로 사용
2. subagent 도구를 평상시 비활성화하는 lite 프로필 제공
3. 글로벌 지침과 자동 스킬 로딩 규칙을 축약
4. 웹 검색 기본 workflow를 `none`으로 변경
5. UI 지연이 있을 때 fullscreen과 custom footer를 별도로 개선

## Current configuration snapshot

### Model and reasoning

`modules/pi/files/settings.json`은 다음을 기본으로 지정한다.

```json
{
  "defaultProvider": "openai-codex",
  "defaultModel": "gpt-5.6-sol",
  "defaultThinkingLevel": "high"
}
```

`modules/pi/files/extensions/codex-fast-mode.ts`는 부모 Pi 세션에서
`service_tier: "priority"`를 추가한다. 이 기능은 지연을 늘리는 설정이 아니라
줄이기 위한 설정이므로 유지하는 것이 합리적이다.

Subagent는 이미 상대적으로 가벼운 라우팅을 사용한다.

- 기본 child: Terra/medium
- scout: Luna
- researcher: Luna/low
- planner, oracle: Sol

즉, 현재 설정 자체도 Luna/Terra를 저비용 또는 빠른 작업 경로로 활용하고 있다.

### Loaded packages

Pi 시작 시 다음 패키지의 extension이 전부 로드된다.

| Package | Version | Main role |
| --- | ---: | --- |
| `@juicesharp/rpiv-ask-user-question` | 2.4.0 | 구조화된 사용자 질문 |
| `pi-web-access` | 0.18.0 | 웹 검색과 콘텐츠 가져오기 |
| `pi-mcp-adapter` | 2.20.1 | MCP proxy 및 scripting |
| `pi-subagents` | 0.41.0 | 위임 및 병렬 worker 실행 |

`pi-subagents`의 bundled skills와 prompts는 이미 필터링되어 있어 해당 부분은
적절하다. MCP server도 기본 lazy lifecycle을 사용하므로 시작 시 서버 연결을
강제하지 않는다.

### Local extensions

관리되는 extension은 다음과 같다.

- `codex-fast-mode.ts`
- `hardware-cursor-only.ts`

`~/.pi/agent/extensions/`에는 Orca가 관리하는 다음 파일도 존재한다.

- `orca-agent-status.ts`
- `orca-prefill.ts`
- `orca-titlebar-spinner.ts`

감사 당시 Pi 프로세스에는 `ORCA_*` 환경 변수가 없었다. 따라서 HTTP status hook과
80ms title spinner는 실행되지 않았고, extension source를 파싱하고 no-op handler를
등록하는 정도의 비용만 발생했다.

## Measurements

### Startup benchmark

모델 호출 없이 resource loading을 비교하기 위해 `pi --list-models`를 사용했다.
`PI_OFFLINE=1`을 적용한 상태에서 반복 실행했으며, 첫 실행은 cold source-loader
비용을 포함한다.

| Scenario | Observed time |
| --- | ---: |
| Full configuration, cold | 2.43s |
| Full configuration, warm | 1.27-1.31s |
| `--no-extensions`, warm | 0.82-0.86s |
| Minimal resources, warm | 0.77-0.82s |
| Full configuration, normal network mode | 1.28s |

결론:

- extension 전체의 warm startup 비용은 약 0.44초다.
- 현재 환경에서는 `PI_OFFLINE=1`이 눈에 띄는 차이를 만들지 않았다.
- context file과 skill descriptor 스캔 비용보다 extension import 비용이 더 컸다.

각 package extension을 단독으로 로드했을 때의 대략적인 warm 결과는 다음과 같다.
수치는 독립 실행 결과이므로 합산 값으로 해석하지 않는다.

| Extension | Time | Approximate increase over minimal baseline |
| --- | ---: | ---: |
| Structured question | 0.95s | +0.13s |
| Web access | 0.87-0.93s | +0.05-0.11s |
| MCP adapter | 1.04s | +0.19-0.22s |
| Subagents | 1.03-1.07s | +0.18-0.25s |
| Managed local extensions | 0.84-0.91s | negligible to small |

### Prompt and tool surface

모델을 호출하지 않는 임시 진단 command로 현재 system prompt와 활성 도구의
크기를 측정했다.

| Metric | Value |
| --- | ---: |
| System prompt | 28,511 chars |
| Loaded context files | 19,220 chars |
| Skill descriptions | 1,387 chars across 5 skills |
| Active tools | 15 |
| Active tool descriptions, schemas, guidelines | 42,255 chars |

Context file breakdown:

| File | Characters |
| --- | ---: |
| Global `~/.pi/agent/AGENTS.md` | 9,154 |
| Repository `AGENTS.md` | 10,066 |

루트에 `CLAUDE.md`도 있지만 Pi 0.84.1은 같은 디렉터리에서 후보 파일 중 첫 번째
파일만 선택하며 `AGENTS.md`가 우선이다. 따라서 루트 `AGENTS.md`와 `CLAUDE.md`가
동시에 모델 context에 들어가지는 않는다.

Active tool breakdown:

| Tool or group | Metadata chars | Share of all tool metadata |
| --- | ---: | ---: |
| `subagent` | 18,171 | 43.0% |
| All subagent-related tools | 21,551 | 51.0% |
| Web tools | 8,429 | 19.9% |
| Structured question | 4,888 | 11.6% |
| MCP and MCP scripting | 4,186 | 9.9% |
| Built-in `read`, `bash`, `edit`, `write` | 3,201 | 7.6% |

Subagent 관련 도구를 비활성화하면 활성 도구 메타데이터는 약 42K자에서 약
21K자로 절반가량 줄어든다. 모든 optional tool을 제거하는 극단적인 구성에서는
약 3.2K자만 남지만, 필요한 기능도 함께 사라지므로 권장하지 않는다.

### Session observations

두 상위 레벨 세션에서 첫 provider request는 각각 14,567 및 14,552 input token을
사용했다. 초기 request에는 cache read가 없었다.

첫 번째 표본 세션의 assistant provider 호출 간격은 약 2.8-24.9초였고 첫 호출은
9.1초였다. 감사 세션은 context가 커진 뒤 35초 이상의 호출도 발생했다. 다만 이
간격은 모델의 순수 TTFT가 아니라 reasoning, output 생성, provider 상태를 모두
포함하므로 모델 간 benchmark로 해석하면 안 된다.

긴 세션에서 cache read가 100K token 이상이어도 새 input과 output이 함께 커지면
호출 시간이 증가할 수 있었다. 자동 compaction은 기본값에서 대략 다음 조건으로
동작한다.

```text
contextTokens > 272K - 16,384
```

즉 약 256K token 전까지 자동 compaction이 시작되지 않는다. 성능을 위해서는
context limit 도달만 기다리기보다 작업 단위가 끝날 때 `/new` 또는 `/compact`를
사용하는 편이 낫다.

## Findings

### 1. Default model and thinking level are quality-biased

**Confidence:** high that the configuration is quality-biased; model-to-model latency
improvement is not directly benchmarked.

모든 요청을 Sol/high로 시작하면 간단한 파일 조회, 문서 수정, 포맷 변경에도 높은
reasoning 경로를 사용한다. 모델과 thinking level은 startup보다 provider response
시간에 직접 영향을 줄 가능성이 크다.

실제 Luna/Terra/Sol A/B 요청은 quota와 외부 호출을 추가로 소비하므로 이번
감사에서는 실행하지 않았다.

### 2. Subagent schema dominates the active tool surface

**Confidence:** high.

`toolDescriptionMode: "compact"`는 이미 적용되어 있으나 tool description보다
schema 자체가 더 크다. 따라서 description을 조금 더 줄이는 것만으로는 효과가
제한적이다.

Subagent 기능을 유지하면서 성능을 개선하려면 extension을 삭제하기보다 다음 중
하나가 적절하다.

- 평상시 subagent 관련 tool을 inactive로 시작하고 `/run` command는 유지
- lite/full launch profile을 분리
- 사용자가 명시적으로 위임을 요청했을 때만 subagent tool을 활성화

### 3. Generic skill policy can add model-tool round trips

**Confidence:** high for matching behavior; exact frequency depends on model decisions.

감사 당시 글로벌 지침은 모든 요청 전에 matching skill을 확인하도록 했고,
범용 코딩 방법론 스킬은 writing, reviewing, refactoring code 전반에 매칭됐다.
따라서 대부분의 코딩 작업에서 모델이 본 작업 전에 `SKILL.md`를 읽는 추가
라운드를 만들 수 있었다.

해당 스킬의 핵심 원칙은 글로벌 지침에도 중복되어 있었다.

- 단순성
- 작은 변경
- 가정 확인
- 검증 가능한 성공 조건
- 관련 없는 변경 금지

후속 변경에서는 이 원칙을 `modules/agent-rules/AGENTS.md`의 항상 로드되는 공통
규칙으로 통합하고, Pi와 Codex의 중복 skill 및 Pi의 필수 routing 규칙을 제거했다.
코딩 규율을 유지하면서 별도 skill `read` 라운드와 에이전트별 동작 차이를 없앴다.

### 4. Always-on instruction duplication was removed

**Confidence:** high.

이전에는 Pi의 system prompt 추가 파일과 글로벌 `AGENTS.md`가 사용자 작업 보존,
승인 경계, 근거, 검증, 최종 보고 규칙을 반복했다. 이 중복은 초기 prompt token을
늘리고, 모델이 같은 규칙을 여러 번 해석하게 만들 수 있었다.

이제 `modules/agent-rules/rules/OPERATING.md`가 공통 operating invariant를 한 번만
정의한다. Pi는 이 파일을 `APPEND_SYSTEM.md`로 로드하고 생성된 `AGENTS.md`에서는
제외한다. Claude Code와 Codex는 같은 파일을 각자의 생성 지침 첫 부분에 포함한다.

### 5. Web search defaults to an additional curator workflow

**Confidence:** high.

`~/.pi/web-search.json`이 존재하지 않아 `pi-web-access`의 기본
`summary-review` workflow가 사용된다. 검색 provider의 응답 뒤에 curator UI와
summary draft 단계가 추가될 수 있다.

일반 coding research에서는 agent가 검색 결과를 직접 소비할 수 있으므로
`workflow: "none"`이 더 빠른 기본값이다. 사람의 source 선택과 review가 필요한
작업만 call parameter 또는 `/curator`로 `summary-review`를 선택할 수 있다.

### 6. Fullscreen and the custom footer can affect UI responsiveness

**Confidence:** medium; TUI interaction benchmark was not performed.

`tuiMode: "fullscreen"`은 Pi 문서에서 experimental로 표시되며 2026-08-07에
최근 활성화됐다. 응답 대기 시간이 아니라 입력, 스크롤, redraw가 느리다면
regular mode와 비교할 가치가 있다.

Custom footer는 render마다 `ctx.sessionManager.getEntries()` 전체를 순회해 누적
토큰을 다시 계산하고, render cache를 사용하지 않는다. 짧은 세션에서는 문제가
작지만 entry가 많은 장기 세션에서는 redraw 비용이 선형으로 증가한다.

### 7. MCP and Orca are not primary current blockers

**Confidence:** high for the audited environment.

- MCP server는 lazy lifecycle이며 metadata cache를 사용한다.
- Cloudflare, Context7 remote server가 선언되어 있어도 시작 시 연결을 강제하지
  않는다.
- Orca runtime marker가 없어 Orca event hook과 spinner는 동작하지 않았다.
- `PI_OFFLINE=1`도 현재 startup benchmark에서는 유의미한 차이가 없었다.

따라서 단순히 remote MCP server를 삭제하거나 offline mode를 강제하는 것은 현재
데이터상 우선순위가 낮다.

## Recommended action items

아래 우선순위는 기대되는 wall-clock 개선, 적용 난이도, 기능 손실 위험을 함께
고려한 것이다.

| Priority | Action | Expected impact | Effort | Main risk |
| --- | --- | --- | --- | --- |
| P0 | 기본 모델을 Terra/medium으로 변경 | High | Low | 복잡한 작업의 품질 저하 가능성 |
| P0 | subagent tool을 기본 inactive로 전환 | High | Medium | 자동 위임이 기본 상태에서 불가능 |
| P1 | 범용 skill과 중복 글로벌 지침 축약 | Medium-High | Medium | 규칙을 과도하게 줄이면 작업 품질 저하 |
| P1 | 웹 검색 workflow를 `none`으로 변경 | High for web tasks | Low | curator 기반 사람 검토가 기본에서 사라짐 |
| P1 | lite/full Pi 프로필 제공 | High | Medium | 프로필 간 기능 차이를 사용자가 기억해야 함 |
| P2 | `mcpScript`와 bundled MCP skill 비활성화 | Low-Medium | Low | 다중 MCP 호출 자동화가 불편해짐 |
| P2 | regular TUI A/B 및 footer 캐싱 | Medium for UI lag | Medium | UI 표시 변경 |
| P2 | 작업 단위별 `/new` 또는 `/compact` 운영 | Medium for long sessions | Low | compaction summary는 손실 압축 |
| Defer | `PI_OFFLINE=1` 상시 적용 | Low in measurements | Low | update/package check가 사라짐 |
| Defer | Orca extension 제거 | Negligible outside Orca | Low | Orca integration 손실 |

### P0: Use Terra/medium as the daily default

**Proposed change**

```json
{
  "defaultModel": "gpt-5.6-terra",
  "defaultThinkingLevel": "medium"
}
```

Sol/high는 다음 상황에 선택적으로 사용한다.

- architecture 또는 migration 결정
- 복잡한 debugging
- 보안 또는 데이터 무결성 검토
- planner와 oracle subagent

**Why first**

- 변경 범위가 설정 두 줄로 작다.
- startup이 아니라 매 provider call에 영향을 줄 수 있다.
- subagent routing에서 이미 동일한 계층화를 사용하고 있다.

**Risk control**

- `/model`과 Shift+Tab으로 즉시 Sol/high로 전환할 수 있게 문서화한다.
- 적용 전후 동일한 대표 작업 3-5개로 latency와 결과 품질을 비교한다.
- 실제 A/B 결과가 좋지 않으면 모델은 Sol로 유지하고 thinking만 medium으로 낮추는
  중간안을 사용한다.

### P0: Keep subagents installed but inactive by default

**Recommended design**

하나의 기능을 제거하기보다 두 프로필로 나눈다.

#### Lite profile

기본 interactive coding에 사용한다.

Inactive candidates:

- `subagent`
- `subagent_wait`
- `subagent_supervisor`
- `intercom`

`/run` 같은 사람이 직접 호출하는 command는 extension이 로드되어 있으면 유지할
수 있다. 자동 위임이 필요한 세션은 full profile로 시작하거나 명시적으로 tool을
활성화한다.

#### Full profile

다음 요청에 사용한다.

- 사용자가 병렬 조사 또는 subagent를 명시적으로 요청
- 여러 독립 subsystem을 동시에 조사
- 별도 reviewer가 필요한 고위험 변경

**Expected reduction**

활성 tool metadata가 약 42,255자에서 약 20,704자로 줄어든다. 실제 provider token
절감량과 latency 변화는 모델 serializer 및 prompt cache에 따라 달라지므로 적용 후
측정해야 한다.

**Implementation options**

1. 작은 Pi extension으로 `session_start` 시 subagent tool을 inactive로 만들고
   `/agents on|off` command 제공
2. shell alias 또는 wrapper로 `--exclude-tools`를 사용하는 `pi-lite` 제공
3. 서로 다른 `PI_CODING_AGENT_DIR` profile 사용

권장 순서는 1 또는 2다. 별도 config directory는 설정 중복과 drift가 생기므로
마지막 선택지로 둔다.

### P1: Consolidate global coding methodology

**Applied changes**

1. 가정과 tradeoff, 단순성, surgical scope, 검증 가능한 목표를
   `modules/agent-rules/AGENTS.md`에 통합한다.
2. 모든 작업에 필요한 안전, 근거, 검증, 보고 invariant는
   `modules/agent-rules/rules/OPERATING.md`에서 관리한다.
3. Claude Code와 Codex는 모든 공통 규칙 뒤에 에이전트별 규칙을 추가한다. Pi는
   operating invariant를 `APPEND_SYSTEM.md`로 로드하고 나머지 공통 규칙 뒤에 Pi
   전용 규칙을 추가한다.
4. Pi와 Codex의 중복 코딩 방법론 skill을 제거하고 Pi의 필수 routing 규칙도
   제거한다.

**Expected impact**

- 코딩 요청 전 선행 skill `read` 라운드 제거
- 에이전트 사이의 코딩 규율 통일
- 같은 원칙의 반복과 drift 감소

**Tradeoff and risk control**

항상 로드되는 공통 지침이 길어지는 대신 별도 skill 선택 여부에 의존하지 않는다.
운영 불변 조건과 coding methodology를 별도 파일에서 관리하므로 Pi가 system
prompt에서 불변 조건을 강제하면서도 같은 규칙을 `AGENTS.md`에서 반복하지 않는다.

### P1: Make raw web results the default

**Applied config**

Pi Web Access의 사용자 설정을 repository-managed resource로 추가했다.

```json
{
  "workflow": "none"
}
```

`summary-review`가 필요한 요청은 tool call의 `workflow` parameter 또는 `/curator`
command로 명시한다.

**Expected impact**

- curator UI 대기 제거
- 추가 summary model call 제거
- web research tool의 반환 시간이 더 예측 가능해짐

**Risk control**

출처를 사람이 선택해야 하는 조사, 외부 공개 문서, 중요한 사실 확인에는
`summary-review` 또는 `source_check`를 명시적으로 사용한다.

### P1: Add explicit lite and full launch paths

모델, thinking, tool surface를 한 번에 바꾸는 launch path를 제공하면 사용자가 매번
수동으로 설정하지 않아도 된다.

예시 목표:

| Profile | Model | Thinking | Optional tools |
| --- | --- | --- | --- |
| `pi` / lite | Terra | medium | no subagent suite, optional `mcpScript` off |
| `pi-full` | Sol | high | all current tools |
| `pi-research` | Terra or Sol | medium/high | web, MCP, subagents enabled |

프로필 이름과 구현 방식은 실제 사용 패턴을 확인한 뒤 결정한다. alias가 너무 많아져
발견성이 떨어지지 않도록 두 개부터 시작하는 것이 좋다.

### P2: Disable MCP scripting when it is rarely used

현재 MCP는 proxy mode로 잘 구성되어 있어 server별 direct tool 폭증 문제는 없다.
다만 `mcpScript`와 `mcp-scripting` skill이 항상 노출된다.

사용 빈도가 낮다면:

- `mcp.json`의 `settings.scriptMode`를 `false`로 설정
- `pi-mcp-adapter` package entry를 object form으로 바꾸고 `skills: []` 지정

이를 통해 약 1.1K자의 tool metadata와 작은 skill descriptor를 제거할 수 있다.
여러 MCP call을 JavaScript로 묶는 작업을 자주 한다면 유지한다.

### P2: Separate UI performance work from provider latency work

UI 입력 또는 스크롤이 느린 경우에만 다음 순서로 확인한다.

1. `tuiMode`를 `regular`로 바꿔 동일 세션에서 비교
2. custom footer의 누적 token 값을 event 기반으로 갱신하거나 render cache 사용
3. built-in footer로 되돌려 비교
4. Orca 내부에서만 느리다면 title spinner 간격과 awaited hook latency 측정

Provider 응답이 느린 문제와 TUI redraw 문제를 한 번에 수정하면 원인 구분이
어려우므로 별도 commit으로 다룬다.

### P2: Manage active context before automatic compaction

권장 운영 기준:

- 하나의 논리적 작업이 끝나면 `/new`
- 긴 조사 또는 큰 tool output이 누적된 후에는 `/compact`
- unrelated task를 같은 session에 계속 추가하지 않음
- `read`와 `bash`에서 필요한 범위만 요청하고 대형 출력은 저장 후 부분 조회

`compaction.reserveTokens`를 크게 올려 조기 자동 compaction을 강제하는 방법도 있지만,
output 공간과 summary 품질에 영향을 주므로 먼저 수동 운영으로 효과를 확인한다.

## Recommended rollout plan

설정과 agent behavior를 동시에 많이 바꾸지 않고 원인별로 효과를 확인한다.

### Phase 1: Low-risk response-latency changes

1. [ ] 기본 thinking을 `medium`으로 변경
2. [ ] 가능하면 기본 모델도 Terra로 변경
3. [x] Web Access workflow를 `none`으로 변경
4. [ ] 대표 작업으로 before/after 측정

**Verification**

- 첫 assistant response까지의 시간
- 전체 작업 완료 시간
- provider input/cache/output token
- 결과의 수정 정확도와 추가 교정 횟수

### Phase 2: Tool-surface reduction

1. lite profile 추가
2. subagent suite를 lite profile에서 inactive로 시작
3. 필요하면 `mcpScript`도 inactive
4. full profile로 기존 기능이 모두 복구되는지 확인

**Verification**

- 진단 command로 active tool count와 metadata chars 재측정
- 일반 코딩 작업에서 subagent를 호출하지 않는지 확인
- `/run` 또는 full profile에서 subagent 실행 확인
- startup benchmark 재실행

### Phase 3: Prompt and skill cleanup

1. 공통 coding methodology를 `modules/agent-rules/AGENTS.md`에서 관리
2. 에이전트별 파일에는 harness-specific rule만 유지
3. specialized skill은 명확히 매칭될 때만 로드
4. 간단한 수정, 복잡한 수정, review 요청을 각각 테스트

**Verification**

- system prompt chars 재측정
- 첫 request input token 비교
- 코딩 요청에서 불필요한 선행 skill read가 없는지 확인
- 안전 규칙과 commit/verification 정책 유지 여부

### Phase 4: UI-only optimization

UI lag가 재현될 때만 진행한다.

1. regular/fullscreen 비교
2. footer scan profiling 또는 caching
3. Orca 안과 밖 비교

**Verification**

- 긴 세션에서 typing, scrolling, resize 체감
- footer token 값 정확성
- IME와 hardware cursor 동작

## Suggested benchmark matrix

실제 변경 전후에는 동일한 prompt와 비슷한 repository 상태에서 최소 3회씩
측정한다.

| Workload | Purpose |
| --- | --- |
| 파일 한 개 읽고 설명 | first response 및 baseline prompt 비용 |
| 단순 single-file 수정 | 일반적인 coding latency와 정확도 |
| 여러 파일 조사 후 변경 | tool round-trip과 context 성장 |
| 웹 문서 조사 | curator/workflow 차이 |
| subagent 조사 | lite/full 기능과 wall-clock 차이 |
| 긴 session에서 추가 요청 | prompt cache와 compaction 영향 |

기록할 항목:

- Pi startup time
- first assistant/tool call time
- final completion time
- model과 thinking level
- input, cache read, output token
- assistant turn 수
- tool call 수
- 추가 수정 또는 사용자 교정 필요 여부

## Deprioritized changes

### Do not prioritize `PI_OFFLINE=1` for speed

이번 측정에서는 normal full startup 1.28초와 offline warm startup 1.27-1.31초가
사실상 동일했다. 네트워크 상태가 나쁜 환경에서는 달라질 수 있지만 현재 데이터만으로
상시 offline mode를 정당화하기 어렵다.

### Do not remove lazy MCP servers only for startup speed

MCP adapter는 lazy connection과 metadata cache를 사용한다. 사용하지 않는 server를
정리하는 것은 구성 단순화에는 도움이 되지만 현재 startup 병목을 크게 해결하지는
않는다.

### Do not remove all skills

Pi skill은 전체 본문이 아니라 name과 description만 startup context에 넣는다.
전문화된 `pi-agent`, `devils-advocate`, `parallel-research-merge`를 제거해 얻는 baseline
절감은 작다. 문제는 skill 수 자체보다 너무 넓은 matching description과 강제 선행
로드 정책이다.

### Do not remove structured questions in the first pass

Structured question tool은 약 4.9K자의 metadata를 사용하지만 모호한 요구사항에서
잘못된 구현을 막는 기능적 가치가 있다. 극단적인 lite profile에서만 제외 여부를
검토하고 기본 개선안에서는 유지한다.

## Limitations

- 실제 Luna/Terra/Sol provider A/B는 추가 quota 사용을 피하기 위해 실행하지 않았다.
- `pi --list-models`는 resource-loading 비교에는 적합하지만 전체 interactive TUI
  startup을 완전히 재현하지는 않는다.
- UI typing, scrolling, resize latency는 계측하지 않았다.
- assistant message 사이의 시간은 순수 TTFT가 아니라 reasoning과 output 생성을
  포함한다.
- prompt 및 schema의 문자 수는 정확히 측정했지만 provider tokenization 결과와
  일대일 대응하지 않는다.
- 감사 중 생성된 긴 세션은 문서 전체 읽기와 병렬 조사 때문에 일반적인 단순 작업보다
  context가 빠르게 증가했다.

## Decision checklist

실제 적용 전에 다음 결정을 내리면 된다.

- [ ] 일상 기본값을 Terra/medium으로 바꿀지 결정
- [ ] lite profile에서 subagent suite를 비활성화할지 결정
- [ ] `/run` command만으로 manual delegation을 허용할지 결정
- [x] Web Access 기본 workflow를 `none`으로 변경
- [x] coding methodology를 `modules/agent-rules/AGENTS.md`로 통합
- [x] 중복 coding methodology skill과 필수 routing 규칙 제거
- [ ] `mcpScript` 사용 빈도를 확인하고 유지 여부 결정
- [ ] UI lag가 실제 증상인지 provider wait가 실제 증상인지 구분

이 checklist가 확정되면 Phase 1부터 작은 rollback 가능한 commit으로 적용하고 각
단계에서 benchmark를 반복하는 것이 권장된다.
