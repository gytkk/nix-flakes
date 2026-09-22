# Codex

`files/config.toml`은 Codex의 기본 모델과 effort, MCP, 기능 설정을 관리한다. 메인 에이전트는 `gpt-6-astra`와 `medium` effort를 사용하며, worker의 기본값은 `gpt-5.6-sol`과 `medium`이다. 세션이나 사용자 설정에서 이 값을 덮어쓸 수 있다.

## 모델별 위임

[Codex adapter](../../agent-core/adapters/codex.md)는 독립적인 작업을 일찍 위임하고, worker를 생성할 때 작업 성격에 맞는 모델과 effort를 명시하도록 지시한다. 메인 에이전트는 사용자와의 대화, 요구사항 해석, 의사결정, 결과 통합과 최종 검증을 담당한다. 모델별 작업 범위와 재위임 기준은 adapter에서 관리한다.

이 동작은 에이전트가 따르는 위임 지침이며, 프롬프트의 복잡도를 계산해 모델을 강제로 선택하는 별도 라우터는 없다. Worker의 모델과 effort 선택은 메인 세션의 모델과 effort를 변경하지 않는다. 생성된 지침과 shared skill의 구조는 [Agent core README](../../agent-core/README.md)에서 확인한다.

## Herdr subagent sidebar

Herdr 안에서 실행한 Codex는 Agents 항목 아래에 실행 중인 직계 subagent의 작업 이름, 실제 모델, 최근 활동을 두 줄씩 표시한다. 이름은 Codex의 `agent_path`에서 가져오며, 모델은 자식 세션의 `turn_context`를 사용한다. 완료되거나 중단된 작업은 숨기고 같은 subagent에 후속 작업을 보내면 다시 표시한다. 별도의 접기 버튼이나 terminal pane은 만들지 않는다. 표시 개수와 레이아웃은 [Herdr README](../herdr/README.md#subagents)에서 확인한다.

[files/hooks.json](files/hooks.json)의 `SessionStart`, `SubagentStart`, `SubagentStop`, `SessionEnd` 훅이 Home Manager로 설치한 `~/.local/bin/codex-herdr-subagents`를 호출한다. 훅은 Herdr pane마다 감시 프로세스 하나를 실행하고, 감시 프로세스는 부모와 자식의 로컬 JSONL 기록을 읽어 `codex:herdr-subagents` metadata를 갱신한다. 부모 세션 종료나 Codex 프로세스 종료 시 표시를 지운다. Metadata는 45초 후 만료되므로 비정상 종료로 정리하지 못해도 오래된 표시가 남지 않는다. Herdr 환경 변수가 없는 터미널에서는 실행하지 않는다.

활동 문구는 assistant 메시지나 도구 종류를 사용한다. 기록이 아직 없으면 `working`을 표시하며, reasoning, 암호화된 메시지, 원시 명령어는 표시하지 않는다. 이 연동은 Codex CLI 0.155.1과 Herdr 0.9.1을 기준으로 검증했다. Codex의 내부 JSONL 형식은 안정된 API가 아니므로 CLI 업데이트 후 표시가 달라지면 parser와 fixture를 함께 확인한다. 동작 검증은 `bun test modules/codex/tests`로 실행한다.

## 적용

Standalone Home Manager는 `/etc/codex/config.toml`을 checkout의 `files/config.toml`에 연결한다. NixOS는 같은 파일을 Nix store에서 설치한다. `~/.codex/config.toml`은 사용자 설정을 보존하며 activation이 덮어쓰지 않는다.

`~/.codex/AGENTS.md`와 `/etc/codex/skills`는 agent-core의 immutable output을 사용한다. Adapter 변경을 적용하려면 환경에 맞는 `home-manager switch --flake .#<environment>` 또는 `nixos-rebuild switch --flake .#<host>`를 사용자가 실행한 뒤 새 Codex 세션을 시작한다.

Herdr 연동도 같은 switch로 훅과 실행 파일을 설치한 뒤 `herdr server reload-config`를 실행하고 Herdr 안에서 새 Codex 세션을 시작한다. 실행 중인 Codex 세션에는 새 훅 설정이 자동 적용되지 않을 수 있다.
