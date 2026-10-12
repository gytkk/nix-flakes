# Skills CLI로 skill 설치를 전환하는 계획

## 결론

Skill 설치는 버전을 고정한 `skills` CLI에 맡기고, agent-core는 지침 문서 생성과 skill source 선언 및 검증을 담당한다. Codex와 Pi는 `~/.agents/skills`를 함께 사용한다. Claude는 `--copy -g`로 독립적인 설치본을 두며, OpenClaw는 기존 external managed 경로에 project copy로 설치한다.

외부 dependency로 우선 전환할 skill은 `mattpocock/skills`의 9개다. 실제 workflow가 다른 `code-review`, `writing-for-agents`와 로컬 수정이 확인된 `pi-agent`, 로컬에서 관리하는 8개는 이 repo를 source로 설치한다. 첫 전환에서는 외부 버전을 올리지 않고, 현재 import의 기준 commit을 사용한다.

이 문서는 Plannotator 피드백을 반영한 계획과 조사 결과다. 구현, dependency 선언 변경, skill 설치, 사용자 설정 변경과 서비스 재시작은 아직 수행하지 않았다.

## 피드백 반영

| 피드백 | 수정한 계획 |
| --- | --- |
| Codex와 Pi의 공통 경로를 분리하지 않는다. | 같은 설치 pool을 사용한다. 이전 계획의 native 제외 설정과 runtime별 격리 검증을 제거한다. 두 runtime에 현재 목록의 합집합 20개가 노출되는 구조로 정리한다. |
| Claude는 `--copy -g`로 설치한다. | Claude의 기존 선택 목록 17개를 `~/.claude/skills`에 복사한다. 공유 pool에 대한 symlink는 만들지 않는다. |
| 원본 그대로 사용할 수 있는 외부 skill은 dependency로 직접 참조한다. | 모든 skill을 이 repo에 vendoring하는 전제를 제거한다. 외부 source와 immutable revision을 선언하고, 로컬 수정본 및 로컬 작성 skill과 구분한다. |

Codex/Pi의 공유 pool은 filesystem과 discovery 위치를 공유하는 선택이다. 보안 격리를 제공하지 않으며, 기존 runtime별 목록을 그대로 유지하는 방식도 아니다. Codex에서 `pi-agent`, Pi에서 `openai-decisions`도 발견할 수 있게 된다. Skill 설치가 관련 package나 credential을 준비해 주지는 않는다.

## 외부 dependency 조사

### 비교 기준과 방법

[현재 catalog 문서](skills/README.md)에 기록된 `mattpocock/skills`의 commit `6654f6b60cd9d5be8b54c6fafe44346dabeb3b76`, version `1.2.3`을 기준으로 11개 imported skill의 전체 파일 목록을 비교했다. 현재 repo의 generated runtime output이 아니라 `agent-core/skills/`의 원본 파일 bytes를 비교했다. 따라서 generated marker 차이는 이 결과에 섞이지 않는다.

7개 skill은 현재 보관 중인 workflow 파일 전체가 upstream과 동일했다. 2개는 보조 스크립트의 주석만 달랐으며, 빈 줄과 comment-only line을 제외한 코드가 동일했다. 나머지 2개는 workflow 지침이 달랐다. 모든 11개에서 upstream의 `agents/openai.yaml`은 현재 repo에 없다. 직접 설치하면 이 파일도 포함되며, 외부 전환 대상 9개의 해당 파일에는 `interface.display_name`과 `interface.short_description`만 있다. 이 UI metadata의 추가는 설치/discovery 테스트에서 확인한다.

`pi-agent`는 repo에 source URL이나 SHA가 기록되어 있지 않았지만, 공개 upstream과 파일 이력을 조사해 비교 가능한 snapshot을 찾았다. 이 snapshot을 최초 import의 기록된 SHA라고 주장하지는 않는다. 비교 결과와 로컬 commit 이력을 근거로 별도로 분류한다.

### 바로 외부 source로 전환할 9개

아래 skill은 모두 같은 upstream commit을 고정한다. 경로는 upstream repo 기준이다.

| Skill | Upstream 경로 | 실제 비교 결과 |
| --- | --- | --- |
| `codebase-design` | `skills/engineering/codebase-design` | `SKILL.md`, `DEEPENING.md`, `DESIGN-IT-TWICE.md`가 동일하다. |
| `domain-modeling` | `skills/engineering/domain-modeling` | `SKILL.md`, `ADR-FORMAT.md`, `CONTEXT-FORMAT.md`가 동일하다. |
| `grilling` | `skills/productivity/grilling` | `SKILL.md`가 동일하다. |
| `prototype` | `skills/engineering/prototype` | `SKILL.md`, `LOGIC.md`, `UI.md`가 동일하다. |
| `research` | `skills/engineering/research` | `SKILL.md`가 동일하다. |
| `resolving-merge-conflicts` | `skills/engineering/resolving-merge-conflicts` | `SKILL.md`가 동일하다. |
| `tdd` | `skills/engineering/tdd` | `SKILL.md`, `mocking.md`, `tests.md`가 동일하다. |
| `diagnosing-bugs` | `skills/engineering/diagnosing-bugs` | `SKILL.md`는 동일하다. [보조 script](skills/diagnosing-bugs/scripts/hitl-loop.template.sh)는 header comment만 다르고 실행 코드는 동일하다. |
| `wizard` | `skills/engineering/wizard` | `SKILL.md`는 동일하다. `template.sh`는 comment만 다르고 실행 코드는 동일하다. |

`diagnosing-bugs`와 `wizard`는 로컬에서 줄이거나 번역한 주석을 유지하기 위해 fork를 보관하지 않는다. Upstream 주석을 그대로 사용하는 것이 이 계획의 의도된 변경이다. Script 동작 자체를 바꾸거나 실행할 필요는 없다.

첫 dependency source는 [mattpocock/skills의 고정 snapshot](https://github.com/mattpocock/skills/tree/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76)이다. `--skill`로 위 9개만 선택한다. Setup skill, user-invoked wrapper와 그 밖의 upstream skill을 함께 설치하지 않는다.

### 로컬 수정본으로 유지할 3개

| Skill | 확인한 차이 | 계획 |
| --- | --- | --- |
| `code-review` | 원본은 issue tracker 문서가 없으면 `/setup-matt-pocock-skills` 실행을 요청한다. 로컬은 repo 문서와 git remote에서 tracker를 발견한다. Spec 조회 단계도 그 workflow를 사용한다. | 제외한 setup skill에 다시 의존하지 않도록 로컬 수정본을 유지한다. |
| `writing-for-agents` | Description과 도입부, `SKILL-MECHANICS.md`의 문구가 다르며, 원본에 없는 `BEHAVIOR-VALIDATION.md`와 이를 읽는 지침이 추가되어 있다. | Skill 선택, 로드, 실행 결과를 구분하는 로컬 검증 지침을 유지한다. |
| `pi-agent` | 아래에서 확인한 upstream snapshot과 frontmatter/prose의 requirement 위치 및 모델 예제가 다르다. | 첫 전환에서는 로컬 수정본을 유지한다. 원본 예제를 그대로 받아들이는 별도 결정이 있으면 외부 dependency로 전환할 수 있다. |

`pi-agent`의 upstream은 [K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills)이며 경로는 `skills/pi-agent`다. Local version `1.2`와 가까운 [commit ef1b2d8026bdccccf8a72f22bf3f2ea9eda76df4](https://github.com/K-Dense-AI/scientific-agent-skills/tree/ef1b2d8026bdccccf8a72f22bf3f2ea9eda76df4/skills/pi-agent)를 비교했다.

- 참고 문서 34개 중 33개는 Git blob hash가 같아서 bytes가 동일함을 확인했다.
- `SKILL.md`에서는 upstream의 Node.js/npm `compatibility` frontmatter가 로컬 본문으로 이동했다. Requirement의 의미는 같다.
- `references/models.md`는 upstream의 `gpt-5.6-sol` 예제가 로컬의 `gpt-6.1-sol` 예제로 변경되어 있다. 로컬 commit `7690a53`과 `a749fbc`에 모델 이름 갱신 이력이 있다.
- Local `LICENSE.md`는 upstream repo root의 `LICENSE.md`와 bytes가 동일하다. Upstream skill 디렉터리에는 이 license 파일이 없다.
- 비교 시점의 최신 skill 변경 commit `a92663a0214b3b9fa1ba6b958284ffd919c00a0c`에서는 `SKILL.md`와 기존 참고 문서 34개가 모두 다르고, `references/mcp.md`가 추가되었다. 최신 원본 채택은 설치 도구 전환과 구분해야 하는 content upgrade다.

따라서 `pi-agent`를 외부로 옮기는 데 기술적인 source 문제가 있는 것은 아니다. 위 고정 snapshot을 참조할 수 있지만, 로컬 모델 예제 변경을 되돌리는 결정이 필요하다. 첫 전환에서는 이 차이를 묵시적으로 없애지 않는다. 이후 외부화한다면 requirement 위치 복원과 예제 변경을 검토하고 license를 포함한다. Runtime의 모델 설정은 변경하지 않는다.

### 로컬에서 관리하는 8개

`data-analysis`, `data-visualization`, `devils-advocate`, `openai-decisions`, `parallel-research-merge`, `repeated-work-analyzer`, `theme-template-authoring`, `user-friction-review`는 catalog 문서상 로컬에서 관리한다. 동일한 외부 원본으로 대체할 근거가 없으므로 이 repo를 source로 사용한다.

Quokka에서 참고한 분석/검증 workflow는 독립적으로 작성한 지침이다. Private Quokka skill dependency로 전환하지 않는다. `openai-decisions`가 사용하는 외부 API와 이 skill 문서의 source도 서로 다른 dependency다.

초기 전환 결과는 외부 9개, 로컬 11개다. 기존 20개 skill의 workflow를 유지하되, 위에서 명시한 주석과 UI metadata 차이는 허용한다.

## Dependency를 참조하는 방식

### CLI 버전과 Git revision 고정

검토한 CLI는 npm 배포본 `skills@1.7.2`이며, npm metadata의 `gitHead`는 `671e8c320810d36fed80fac5f1a2c1bf7e82d812`다. 해당 버전의 bundle을 읽었고, 코드를 실행하거나 package를 설치하지 않았다.

이 버전은 GitHub `/tree/<ref>` URL과 `#<ref>`를 파싱한다. 40자리 SHA는 branch clone 실패 후 `git fetch --depth 1 origin <SHA>`로 취득하는 fallback을 갖고 있다. 두 upstream의 위 고정 SHA를 별도 임시 Git 디렉터리에서 실제로 fetch하고 `FETCH_HEAD` 일치를 확인했다. 이는 Git 취득 검증이며, `npx skills` 설치의 end-to-end 검증은 아직 아니다.

`owner/repo@<SHA>`는 사용하지 않는다. 이 CLI에서 `@...`는 revision이 아니라 skill 이름 filter다. `latest`, `main`과 이동 가능한 tag를 첫 전환의 source 고정 수단으로 사용하지 않는다.

설치 형태의 예시는 다음과 같다. 아직 실행하지 않은 명령이며, 실제 전환에서는 manifest로부터 source와 선택 목록을 전달한다.

```bash
DISABLE_TELEMETRY=1 npx --yes skills@1.7.2 add \
  https://github.com/mattpocock/skills/tree/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76 \
  --skill codebase-design domain-modeling grilling prototype research \
    resolving-merge-conflicts tdd diagnosing-bugs wizard \
  --agent codex pi --global --yes
```

Claude에는 같은 source와 9개 목록을 `--agent claude-code --copy --global`로 설치한다. Local source는 이 repo checkout의 `agent-core/skills/` 절대 경로다. 상대 source 경로를 OpenClaw의 별도 작업 디렉터리에 잘못 적용하지 않는다.

첫 npx 실행에는 npm 접근이, 외부 Git source 취득에는 GitHub 접근이 필요할 수 있다. Nix 빌드와 Home Manager activation 안에서는 npm 설치나 외부 skill 다운로드를 수행하지 않는다. 설치는 명시적인 사용자 실행 작업이며, network 실패를 성공으로 처리하지 않는다.

### 하나의 source 선언과 설치 정책

기존 [manifest](manifest.toml)에 skill 이름과 source의 대응을 선언한다. Local source와 external source를 구분하고, external에는 repo URL, 40자리 commit SHA, 선택할 이름과 upstream 경로를 기록한다. Runtime별 설치 대상도 같은 manifest에서 정한다. Module마다 skill 목록을 복제하거나 CLI가 manifest를 직접 해석한다고 가정하지 않는다.

초기 선언은 external source 하나에 위 9개, local source에 나머지 11개다. Codex/Pi는 합집합 20개를 하나의 pool로 설치하고, Claude는 기존 17개, OpenClaw는 기존 16개를 선택한다. Local source에서 external source로 옮긴 이름이 동시에 두 source에 선언되면 오류로 처리한다.

`package.json`의 `skills` field와 `experimental_sync`도 조사했다. 검토한 배포본에는 Git source 선언과 설치 처리가 있지만, local directory를 해당 field에 넣으면 `is not a git source` 오류가 된다. 또한 remote 설치 경로에는 copy 설정 전달을 별도로 확인해야 한다. 이 experimental 기능을 기반으로 새 npm project나 `node_modules` 관리 구조를 추가하지 않는다. 작은 연결 명령이 manifest의 source별 선택 목록을 CLI의 안정적인 `add` 명령에 전달하는 방식을 사용한다.

CLI의 global lock `~/.agents/.skill-lock.json`과 project lock `skills-lock.json`은 설치 기록으로 취급한다. 이를 전체 source 선언이나 frozen dependency resolver로 간주하지 않는다. Hash 기록만으로 원본 revision이 고정되지는 않는다. Source commit을 manifest에 고정하고, 재설치는 그 선언에서 수행한다. CLI의 `update`가 임의로 최신 upstream을 선택하도록 자동 실행하지 않는다.

MIT notice는 보존한다. Matt의 현재 `skills/LICENSE`는 고정 upstream의 root `LICENSE`와 동일하다. CLI가 root license를 skill 디렉터리에 자동으로 포함한다고 가정하지 않으며, 설치 결과에 notice가 없으면 같은 revision의 license를 설치본에 포함하는 최소한의 metadata 단계를 둔다. License 보완 파일은 content 검증과 ownership 기록에서 명시적으로 구분한다. Skill 본문에 로컬 patch를 다시 적용하는 방식으로 외부 dependency를 유지하지 않는다.

## 목표 설치 구조

| Runtime | Repo-managed skill 수 | 설치 위치와 방식 |
| --- | --- | --- |
| Codex/Pi | 공통 20개 | `~/.agents/skills`에 공통 pool로 global 설치한다. 두 runtime을 분리하는 경로나 native 제외 설정을 추가하지 않는다. |
| Claude | 17개 | `~/.claude/skills`에 `--copy --global`로 설치한다. Marketplace plugin skill은 그대로 유지한다. |
| OpenClaw | 16개 | `~/.local/share/openclaw/agent-core`에서 project `--copy`를 실행해 그 아래 `skills`에 설치한다. Mutable OpenClaw state로 옮기지 않는다. |

Shared global pool은 Claude와 별개로 갱신한다. 원본 수정이 checkout에서 설치본으로 실시간 반영되는 것은 아니다. 외부 source의 SHA 변경과 local source 수정 모두 해당 CLI 설치 명령의 재실행이 필요하다.

OpenClaw의 기존 `skills.load.extraDirs`, prompt hook, extension materialization과 service drop-in은 유지한다. 위 external 경로에 ordinary file로 설치해 symlink와 Nix store hardlink를 피한다. Linux host에서 실제 discovery를 확인하기 전에는 전환 완료로 보고하지 않는다.

## 구현 단계

### 1. Source 선언과 격리된 설치 검증

1. Manifest schema에 mixed source 선언을 추가하고 이름 중복, full SHA, 경로, local source 존재와 external 선택 목록을 검증한다. Dependency 선언 변경은 계획 승인 후 수행한다.
2. Pure renderer는 홈 디렉터리나 네트워크를 읽지 않게 유지한다. Local skill에는 기존 구조 검증을 적용하고 external source에는 선언 검증을 적용한다. External 파일 자체의 구조와 bytes는 취득 후 별도 검증한다.
3. 임시 HOME, XDG 경로, npm cache와 작업 디렉터리에서 pinned CLI를 실행하는 fixture test를 추가한다. User credential과 runtime 설정을 복사하거나 untrusted 보조 script를 실행하지 않는다.
4. 실제 external 9개의 source SHA와 파일 목록, 보조 문서 및 script, UI metadata와 license를 확인한다. `--skill`이 의도한 9개만 선택하는지 확인한다.
5. Claude copy, Codex/Pi shared pool, OpenClaw project copy, 재설치와 파일 삭제 반영을 확인한다. Root checkout에 `.agents/`나 설치 lock이 생기지 않게 한다.

완료 조건: external 9개와 local 선택 목록을 원하는 설치 위치에 배치할 수 있고, 모든 필수 파일이 있으며, 실제 runtime loader가 설치 결과를 발견해야 한다. CLI 실행 성공만으로 이 조건을 충족했다고 판단하지 않는다.

### 2. 사용자 설치 명령과 안전한 갱신

1. Agent-core에 source별 선택 목록을 읽기 전용으로 출력하는 작은 interface를 마련한다. Host 경로와 CLI 실행은 runtime integration이 담당하고 pure renderer에 넣지 않는다.
2. Source 취득과 agent directory 배치는 CLI에 맡긴다. 자체 downloader, copy engine, skill router를 만들지 않는다. 연결 명령은 선언 전달, 충돌 사전 검사와 결과 검증에 한정한다.
3. 실행 전 변경 계획을 출력하고, 동명 타 source 설치나 local edit가 있는 경로는 덮어쓰지 않고 중단한다. CLI installer가 기존 skill directory를 삭제한 뒤 재복사한다는 점을 반영한다.
4. 기존 CLI lock과 설치 당시 source/content 기록으로 이 repo가 관리하는 항목을 구분한다. 그 기록만으로 변경 감지가 부족하면 최소한의 ownership 기록을 추가하고, 복잡한 별도 설치 framework로 확대하지 않는다.
5. Source 간 이동과 stale skill 정리는 이전 관리 대상과 content를 확인하고 사용자 승인 후 수행한다. Shared pool에서 다른 runtime이 사용하는 항목과 marketplace 또는 개인 skill은 삭제하지 않는다.
6. Network 또는 부분 설치 실패 시 source, skill, 대상 경로와 실패 단계를 보고한다. 새 성공 상태를 기록하지 않고, backup으로 복구할 수 있게 한다.

완료 조건: 재실행 결과가 같고, local/external source를 동일한 명령으로 갱신할 수 있으며, 사용자 변경과 관련 없는 skill을 보존한다.

### 3. 설치 소유권 전환

1. [Claude module](../modules/claude/default.nix)의 `~/.claude/skills`, [Pi module](../modules/pi/default.nix)의 `~/.pi/agent/skills`에 대한 directory-level Home Manager 선언을 제거한다. 생성 지침과 runtime 설정은 유지한다.
2. [Codex system module](../modules/codex/system.nix)의 `/etc/codex/skills` 선언과 [standalone activation](../modules/codex/system-activation.nix)의 해당 skill link 관리만 제거한다. `/etc/codex/config.toml`과 사용자 지침 설치는 유지한다.
3. [OpenClaw Home Manager module](../modules/openclaw/home.nix)의 skill materialization만 제거한다. Context hook과 session-record extension, 생성 지침 및 service drop-in은 유지한다.
4. 기존 경로와 새 CLI 경로의 타입, content와 충돌을 먼저 확인한다. Backup 후 사용자가 Home Manager/NixOS switch를 실행하고, 그 다음 CLI 설치 명령을 실행한다. Legacy path 제거는 관리 중인 경로임을 확인하고 승인한 경우에만 수행한다.
5. Standalone Codex의 `/etc/codex/skills`는 선언 제거만으로 남을 수 있으므로 별도로 점검한다. OpenClaw의 read-only materialized tree도 backup 후 copy 설치본으로 전환한다. 사용자 파일에 대한 포괄적인 recursive delete는 하지 않는다.
6. 실제 runtime 목록과 중복 discovery를 확인한다. OpenClaw의 pylv-onyx 확인이 불가능하면 해당 host의 실제 전환을 보류하고 미검증으로 보고한다.

완료 조건: 설치 경로별 담당자가 하나뿐이며, legacy와 새 설치본이 중복 노출되지 않는다. Codex/Pi 공통 20개, Claude 17개, OpenClaw 16개가 각 runtime에서 발견된다. 관련 없는 skill과 plugin은 남아 있어야 한다.

### 4. Vendoring과 renderer 정리

1. External 설치 검증과 전환 확인 후에만 9개 vendored 디렉터리를 제거한다. Local 수정본 3개와 로컬 관리 8개, 필요한 license notice는 유지한다.
2. Agent-core의 skill 배포 tree 생성과 generated skill marker를 제거한다. 지침 문서 bytes는 변경하지 않는다. External dependency 내용은 지침 render에 합치지 않는다.
3. Source 검증, 선택 정책과 pure document render 테스트를 유지한다. External 취득/설치/discovery는 별도 integration test로 분리한다. Offline `agent-core check`가 없는 external local directory를 요구하지 않게 한다.
4. `flake.nix`의 source wiring assertion을 새 구조로 바꾸고, 의도된 output layout 변경을 검토한 뒤 golden hash를 갱신한다. Skill 설치 검증을 없애는 대신 CLI integration과 runtime smoke test로 옮긴다.
5. Agent-core와 각 runtime의 기존 README, root 문서의 관련 설명을 갱신한다. Content upgrade와 설치 도구 전환, native shared discovery와 copy 설치를 구분해 설명한다.

완료 조건: 외부 9개의 원문 복사본과 별도 배포 구현이 없어지고, 지침 생성 및 로컬 source 검증은 계속 재현 가능하다. External source의 revision과 취득 후 검증 책임이 명확하다.

## 검증과 rollback

- Unit test는 mixed source 선언, 중복 이름, SHA와 경로, target별 선택 목록, 지침 bytes 보존을 확인한다.
- Installer test는 exact SHA 설치, local 수정 반영, 재실행, 선택 목록 변경, 동명 충돌, 사용자 수정, 삭제, license 누락, 부분 실패와 무관한 skill 보존을 확인한다.
- Runtime smoke test는 위 개수뿐 아니라 이름과 source 경로를 확인한다. Codex/Pi에는 native 격리나 제외 설정을 추가하지 않는다. Claude plugin과 OpenClaw workspace override 및 prompt hook이 유지되는지 확인한다.
- `uv run --project agent-core -m pytest agent-core/tests`, `uv run --project agent-core agent-core check`와 바뀐 범위의 runtime test를 실행한다. 변경 Nix 파일에 `nixfmt`를 적용하고 source wiring 변경에 필요한 targeted evaluation만 수행한다. Package build는 기본적으로 하지 않는다.
- 문서는 `uv run --no-project scripts/check-paths.py`로 검사하고 필요한 변경 Markdown을 명시한다. Model 호출이나 실제 서비스 재시작은 discovery 검사에 불필요하면 하지 않는다.
- Rollback은 이전 repo commit과 Nix generation, native 설치/설정 backup을 사용한다. CLI 설치 상태는 Nix generation 밖에 있으므로 Nix rollback만으로 복원된다고 안내하지 않는다. Repo-owned 설치만 점검해 되돌리고, shared pool과 unrelated user skill을 보존한다.
- 구현은 source 선언과 CLI integration, runtime 전환과 obsolete render/vendoring 정리의 검증 가능한 단위로 나눠 local commit을 남긴다. Push, switch/rebuild와 실제 사용자 상태 변경은 자동 수행하지 않는다.

## 조사에서 검증한 것과 남은 확인

검증한 사항은 Matt의 11개 전체 file-set/bytes 비교, 보조 script 2개의 non-comment code 일치, Pi baseline의 34개 참고 문서 Git blob 비교, 달라진 Pi 본문과 모델 예제 및 license 비교, 최신 Pi snapshot의 변경 목록, npm CLI 배포본의 parser/installer 읽기, 두 full SHA의 shallow fetch다. Git/network 취득은 임시 디렉터리에서만 수행했다.

아직 검증하지 않은 사항은 `skills@1.7.2`의 실제 설치 실행, lock/overwrite/retry의 end-to-end 동작, runtime에서의 실제 discovery와 copy/metadata 영향, Linux OpenClaw 전환이다. 이는 구현 1단계의 전환 조건이며, 구조나 bytes 비교를 skill 행동 검증으로 보고하지 않는다.

## 근거

- [현재 skill catalog와 import 기록](skills/README.md), [runtime 선택 manifest](manifest.toml), [renderer](src/agent_core/core.py), [renderer 테스트](tests/test_core.py).
- [Matt upstream 고정 tree](https://github.com/mattpocock/skills/tree/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76), [code-review 원본](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/skills/engineering/code-review/SKILL.md), [writing-for-agents 원본](https://github.com/mattpocock/skills/tree/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/skills/productivity/writing-for-agents).
- [Pi 비교 baseline](https://github.com/K-Dense-AI/scientific-agent-skills/tree/ef1b2d8026bdccccf8a72f22bf3f2ea9eda76df4/skills/pi-agent), [baseline 모델 예제](https://github.com/K-Dense-AI/scientific-agent-skills/blob/ef1b2d8026bdccccf8a72f22bf3f2ea9eda76df4/skills/pi-agent/references/models.md), [baseline license](https://github.com/K-Dense-AI/scientific-agent-skills/blob/ef1b2d8026bdccccf8a72f22bf3f2ea9eda76df4/LICENSE.md), [최신 skill 변경 snapshot](https://github.com/K-Dense-AI/scientific-agent-skills/tree/a92663a0214b3b9fa1ba6b958284ffd919c00a0c/skills/pi-agent).
- [skills@1.7.2 npm 배포본](https://registry.npmjs.org/skills/-/skills-1.7.2.tgz), [해당 gitHead의 source parser](https://github.com/vercel-labs/skills/blob/671e8c320810d36fed80fac5f1a2c1bf7e82d812/src/source-parser.ts), [Git 취득 코드](https://github.com/vercel-labs/skills/blob/671e8c320810d36fed80fac5f1a2c1bf7e82d812/src/git.ts), [installer](https://github.com/vercel-labs/skills/blob/671e8c320810d36fed80fac5f1a2c1bf7e82d812/src/installer.ts), [CLI README](https://github.com/vercel-labs/skills/blob/671e8c320810d36fed80fac5f1a2c1bf7e82d812/README.md).
