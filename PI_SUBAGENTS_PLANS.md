# Pi Subagents 도입 계획

## 상태

- `pi-subagents` `0.41.0` 도입 설정을 구현했다.
- 대상 Pi 버전은 `0.83.0`이다.
- package cache에는 `pi-subagents@0.41.0`이 설치됐지만 runtime config
  symlink는 Home Manager 적용 전이라 아직 없다.
- Home Manager 적용과 새 Pi session에서의 runtime 검증은 아직 남아 있다.
- 사용자는 `nicobailon/pi-subagents` 사용과 보수적인 1차 rollout을 승인했다.

## 목표

`modules/pi`에 `pi-subagents`를 추가하되 다음 원칙을 지킨다.

- 처음에는 built-in agent만 사용한다.
- child 실행은 기본적으로 foreground에서 관찰 가능해야 한다.
- 프로젝트 디렉터리에 runtime artifact를 남기지 않는다.
- 병렬 실행 수와 세션별 spawn 수를 제한한다.
- mutation-capable child는 항상 하나만 실행한다.
- 이 저장소에서는 Git worktree를 사용하지 않는다.
- missions, schedules, watchdog, persistent memory는 첫 단계에서 비활성화한다.
- 모델 선택과 비용이 예측 가능해야 한다.

## 조사 결과

### 현재 구성과의 호환성

현재 `modules/pi`에는 Codex tool-conversion adapter가 설치되어 있지 않다.
따라서 built-in subagent가 선언하는 `read`, `bash`, `edit`, `write` 등의
Pi-native tool 이름이 현재 tool surface와 일치한다.

`researcher`가 요구하는 `web_search`, `fetch_content`,
`get_search_content`는 이미 설치된 `pi-web-access`가 제공한다.

### 기본값을 그대로 사용하지 않는 이유

`pi-subagents`의 주요 기본값은 현재 저장소에 지나치게 적극적이다.

| 항목 | 패키지 기본값 | 위험 |
| --- | --- | --- |
| 실행 방식 | background 기본 | 첫 도입 시 실행 상태와 실패 원인 추적이 어려움 |
| artifacts | 프로젝트의 `.pi-subagents/` | 저장소에 runtime 파일 생성 |
| missions | 자동 생성 활성화 | durable project state 기록 |
| schedules | 활성화 | 의도하지 않은 지속 작업 가능 |
| parallel | 최대 8개, 동시 4개 | 모델 사용량 급증 가능 |
| global concurrency | 20 | 현재 사용 범위에는 과도함 |
| nested delegation | 최대 depth 2 | 불필요한 재귀 delegation 가능 |
| UI | FleetView와 async widget 활성화 | 기존 custom footer와 화면이 혼잡해질 수 있음 |

### Worktree 제한

패키지 설정에는 worktree 생성을 전역으로 금지하는 옵션이 없다.
`authorityPolicy`는 worktree 폐기 승인을 제어하지만 생성을 차단하지는
않는다.

따라서 첫 단계에서는 다음 운영 규칙으로 제한한다.

- 이 저장소의 `AGENTS.md`에 있는 worktree 금지 규칙을 유지한다.
- 저장된 chain이나 prompt에 `worktree: true`를 넣지 않는다.
- 병렬 작업은 read-only agent에만 사용한다.
- worker 또는 다른 mutation-capable agent는 한 번에 하나만 실행한다.
- 런타임 검증에서 `git worktree list`를 확인한다.

## 권장 설정

### 패키지 및 모델 라우팅

`modules/pi/files/settings.json`의 package 목록에 다음 pin을 추가한다.
번들 skill과 prompt는 0.41.0의 async/workflow 우선 지침을 자동으로
불러오지 않도록 제외한다.

```json
{
  "source": "npm:pi-subagents@0.41.0",
  "skills": [],
  "prompts": []
}
```

같은 파일에 다음 `subagents` 설정을 추가한다.

```json
{
  "subagents": {
    "defaultModel": "openai-codex/gpt-5.6-terra",
    "defaultThinking": "medium",
    "modelScope": {
      "enforce": true,
      "allow": [
        "openai-codex/gpt-5.6-luna",
        "openai-codex/gpt-5.6-terra",
        "openai-codex/gpt-5.6-sol"
      ]
    },
    "agentOverrides": {
      "scout": {
        "model": "openai-codex/gpt-5.6-luna",
        "tools": ["read", "grep", "find", "ls", "bash", "intercom"]
      },
      "researcher": {
        "model": "openai-codex/gpt-5.6-luna",
        "thinking": "low",
        "tools": ["read", "web_search", "fetch_content", "get_search_content", "intercom"]
      },
      "worker": {
        "thinking": "medium"
      },
      "reviewer": {
        "thinking": "medium",
        "acceptanceRole": "read-only",
        "tools": ["read", "grep", "find", "ls", "bash", "intercom"]
      },
      "context-builder": {
        "tools": ["read", "grep", "find", "ls", "bash", "web_search", "intercom"]
      },
      "planner": {
        "model": "openai-codex/gpt-5.6-sol"
      },
      "oracle": {
        "model": "openai-codex/gpt-5.6-sol"
      },
      "delegate": {
        "disabled": true
      }
    }
  }
}
```

역할별 기본 라우팅은 다음과 같다.

| 역할 | 모델 | Thinking | 비고 |
| --- | --- | --- | --- |
| `scout` | Luna | low | 빠른 로컬 코드 탐색 |
| `researcher` | Luna | low | 웹 및 문서 조사 |
| `worker` | Terra | medium | 단일 구현 writer |
| `reviewer` | Terra | medium | edit/write 없는 독립 검토 |
| `context-builder` | Terra | medium | 구현 전 context 구성 |
| `planner` | Sol | high | 구현 계획 작성 |
| `oracle` | Sol | high | 고비용 의사결정 검증 |
| `delegate` | 비활성화 | - | 모호한 범용 delegation 방지 |

첫 단계에서는 fallback model을 설정하지 않는다. 모델 장애가 발생했을
때 더 강한 모델로 자동 승격하기보다 명시적으로 실패하게 하여 비용과
동작을 예측 가능하게 유지한다.

`modelScope.enforce`는 사용자가 명시적으로 전달하는 범위 밖 모델을
차단한다. 설정이나 parent session에서 상속된 범위 밖 모델은 패키지
정책상 경고만 발생할 수 있으므로 `/subagents-models` 검증이 필요하다.

### Runtime 제한

새 파일
`modules/pi/files/extensions/subagent/config.json`을 다음과 같이 만든다.

```json
{
  "asyncByDefault": false,
  "forceTopLevelAsync": false,
  "toolDescriptionMode": "compact",
  "inlineToolDisplay": "summary",
  "fleetView": true,
  "fleetViewPlacement": "aboveEditor",
  "asyncWidget": false,
  "artifactDir": "session",
  "maxSubagentDepth": 1,
  "maxSubagentSpawnsPerSession": 8,
  "globalConcurrencyLimit": 2,
  "parallel": {
    "maxTasks": 4,
    "concurrency": 2
  },
  "scheduledRuns": {
    "enabled": false
  },
  "missions": {
    "enabled": false
  },
  "proactiveSkillSubagents": false,
  "authorityPolicy": {
    "scheduleCreate": "forbid"
  }
}
```

설정 의도:

- top-level child는 foreground 기본
- artifact는 Pi session 디렉터리에 저장
- legacy multi-child 경로에서는 동시에 최대 2개 child 실행
- 한 parent session에서 최대 8개 child spawn
- direct child는 실행할 수 있지만 child의 추가 delegation은 차단
- schedules와 자동 mission 생성 비활성화
- proactive subagent 추천 비활성화
- FleetView는 유지하되 중복 async widget 제거
- compact tool description으로 parent context 사용량 절감
- 1차 rollout에서는 direct foreground child만 사용하고 `workflowScript`,
  background 실행, worktree를 요청하지 않음

`globalConcurrencyLimit`와 `parallel` 설정은 0.41.0의 legacy multi-child
경로에만 적용된다. 신규 `workflowScript`의 `runs.all()` 동시 실행을 hard
cap하지 않으므로 이를 동시 실행 보장으로 간주하지 않는다.

`defaultSessionDir`와 `singleRunOutputBaseDir`은 설정하지 않는다.
`artifactDir: "session"`과 parent session에서 파생되는 기본 경로를
사용하는 편이 경로 관리가 단순하다.

전역 `turnBudget`, `toolBudget`, `usageBudget`도 설정하지 않는다.
Mutation-capable child를 작업 중간에 종료하면 검증되지 않은 파일 상태가
남을 수 있으므로, worker는 좁은 task와 충분한 외부 timeout으로
제어한다.

### Fast mode 격리

현재 `modules/pi/files/extensions/codex-fast-mode.ts`는 모든
`openai-codex` 요청에 `service_tier: "priority"`를 추가한다.
Subagent child도 ambient extension을 로드하므로 아무 조치가 없으면 모든
병렬 child 요청이 priority tier를 사용한다.

권장안은 child process를 다음 환경변수로 식별하는 것이다.

```text
PI_SUBAGENT_PARENT_SESSION
```

이 값이 있으면 `codex-fast-mode.ts`가 priority request field를 추가하지
않도록 한다.

결과:

- parent Pi session은 현재처럼 fast mode를 사용한다.
- child subagent는 일반 service tier를 사용한다.
- 병렬 실행으로 priority 사용량이 예상보다 커지는 것을 방지한다.

이 정책을 구현해 parent만 fast mode를 사용하고 child는 일반 tier를
사용한다.

## Home Manager wiring

`modules/pi/default.nix`에 다음 파일 연결을 추가한다.

```nix
home.file.".pi/agent/extensions/subagent/config.json".source =
  mkSymlink "files/extensions/subagent/config.json";
```

패키지가 읽는 정확한 runtime 경로는 다음과 같다.

```text
~/.pi/agent/extensions/subagent/config.json
```

## 구현 대상 파일

| 파일 | 변경 |
| --- | --- |
| `modules/pi/files/settings.json` | package pin과 모델 라우팅 추가 |
| `modules/pi/files/extensions/subagent/config.json` | 보수적인 runtime 설정 추가 |
| `modules/pi/files/extensions/codex-fast-mode.ts` | child fast-mode guard 추가 |
| `modules/pi/default.nix` | subagent config symlink 연결 |
| `modules/pi/README.md` | 실제 활성화된 subagent 구성과 운영법 문서화 |

첫 단계에서는 custom agent, saved chain, watchdog, persistent memory,
provider profile을 추가하지 않는다.

## 구현 순서

1. `config.json`을 먼저 추가하고 JSON 문법을 검증한다.
2. `default.nix`에 runtime config symlink를 추가하고 `nixfmt`를 실행한다.
3. `settings.json`에 package pin과 모델 라우팅을 추가한다.
4. `codex-fast-mode.ts`에 child guard를 추가한다.
5. README에 실제 설정, 역할, 제한, 운영 명령을 추가한다.
6. 전체 diff와 정적 검증을 완료한다.
7. 하나의 rollback 가능한 Pi subagent 도입 커밋으로 남긴다.
8. Home Manager 적용 후에만 Pi를 재시작하고 런타임 검증을 수행한다.

## 정적 검증

```bash
jq -e . modules/pi/files/settings.json
jq -e . modules/pi/files/extensions/subagent/config.json
nixfmt modules/pi/default.nix
nix flake check --no-build
git diff --check
git status --short
```

확인할 사항:

- diff에 의도하지 않은 package나 model 변경이 없어야 한다.
- credential, OAuth token, session artifact가 포함되지 않아야 한다.
- `pi-subagents` package version이 정확히 pin되어야 한다.
- runtime config path가 패키지가 요구하는 경로와 일치해야 한다.

## 적용 및 런타임 검증

Home Manager 적용은 사용자가 수행한다.

```bash
home-manager switch --flake .#<environment>
```

그 후 새 Pi session에서 다음을 검증한다.

1. `pi list`에 `pi-subagents@0.41.0`이 표시되는지 확인한다.
2. `/subagents-doctor`가 configuration error 없이 통과하는지 확인한다.
3. `/subagents-models`에서 모든 built-in agent의 모델과 thinking을 확인한다.
4. foreground `scout`를 실행하여 Luna/low와 project instruction 상속을 확인한다.
5. `researcher`를 실행하여 `pi-web-access` 도구 사용을 확인한다.
6. read-only `reviewer`에서 `edit`과 `write`가 노출되지 않는지 확인한다.
7. persisted parent session에서 `planner` fork 실행을 확인한다.
8. worker 검증은 임시 fixture에서 수행하여 실제 저장소 변경을 피한다.
9. artifact가 Pi session 디렉터리에 생성되는지 확인한다.
10. 저장소에 `.pi-subagents/`나 `progress.md`가 생성되지 않았는지 확인한다.
11. `git worktree list`에 새 worktree가 없는지 확인한다.
12. 1차 검증에서는 direct foreground child를 한 번에 하나만 실행하고
    `workflowScript`가 사용되지 않았는지 확인한다.
13. parent `/fast status`가 기존대로 동작하고 child tier 정책이 승인안과 일치하는지 확인한다.
14. 마지막으로 `git status --short`가 예상 상태인지 확인한다.

## Rollout 주의사항

`~/.pi/agent/settings.json`은 현재 repository source를 직접 가리키는
out-of-store symlink다. 따라서 `modules/pi/files/settings.json`에 package를
추가하면 Home Manager를 다시 적용하기 전이라도 다음 Pi 시작 시 새
package 설정이 보일 수 있다.

반면 새 `extensions/subagent/config.json` symlink는 Home Manager를
적용해야 생성된다. 이 사이에 Pi를 재시작하면 package가 보수적인 설정
없이 기본값으로 로드되어 project artifact나 자동 mission을 만들 수
있다.

따라서 구현 후 순서는 반드시 다음과 같아야 한다.

1. 변경사항과 커밋 검토
2. `home-manager switch`
3. Pi 재시작 또는 `/reload`
4. 런타임 검증

Home Manager 적용 전에는 새 Pi process를 시작하거나 `/reload`하지
않는다.

## 후속 단계 후보

1차 도입이 안정화된 뒤 필요할 때만 검토한다.

- 반복 workflow를 위한 saved chain
- 역할별 custom agent
- provider failure용 fallback model
- watchdog 기반 자동 리뷰
- project 또는 user-scoped persistent memory
- package profile 생성과 전환
- child별 extension allowlist
- hard worktree-disable 정책을 제공하는 별도 extension

## 확정된 결정사항

- parent만 fast mode를 사용하고 child는 일반 tier를 사용한다.
- package의 extension만 로드하고 번들 skill과 prompt는 제외한다.
- 1차 rollout은 direct foreground child만 사용한다.
- 병렬 `workflowScript`, background 실행, worktree는 후속 검토 전까지
  사용하지 않는다.
