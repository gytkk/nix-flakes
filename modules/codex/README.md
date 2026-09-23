# Codex

`files/config.toml`은 Codex의 기본 모델과 effort, MCP, 기능 설정을 관리한다. 메인 에이전트는 `gpt-6-astra`와 `high` effort를 사용하며, worker의 기본값은 `gpt-5.6-terra`와 `medium`이다. 세션이나 사용자 설정에서 이 값을 덮어쓸 수 있다.

## 모델별 위임

[Codex adapter](../../agent-core/adapters/codex.md)는 독립적인 작업을 일찍 위임하고, worker를 생성할 때 작업 성격에 맞는 모델과 effort를 명시하도록 지시한다. 메인 에이전트는 사용자와의 대화, 요구사항 해석, 의사결정, 결과 통합과 최종 검증을 담당한다. 모델별 작업 범위와 재위임 기준은 adapter에서 관리한다.

이 동작은 에이전트가 따르는 위임 지침이며, 프롬프트의 복잡도를 계산해 모델을 강제로 선택하는 별도 라우터는 없다. Worker의 모델과 effort 선택은 메인 세션의 모델과 effort를 변경하지 않는다. 생성된 지침과 shared skill의 구조는 [Agent core README](../../agent-core/README.md)에서 확인한다.

## Herdr subagent sidebar

Herdr 안에서 실행한 Codex는 Agents 항목 아래에 직계 subagent의 상태, 작업 이름, 실제 모델, 최근 메시지를 두 줄씩 표시한다. 첫 줄에는 상태 아이콘, 이름, 모델만 표시하고 둘째 줄의 메시지는 옅게 표시한다. 이름은 Codex의 `agent_path`에서 가져오며, 모델은 자식 세션의 `turn_context`를 사용한다. 별도의 접기 버튼이나 terminal pane은 만들지 않는다. 표시 개수와 레이아웃은 [Herdr README](../herdr/README.md#subagents)에서 확인한다.

상태는 Codex의 작업 이벤트로 결정한다. 실행 중은 초록색 `●`, 완료는 파란색 `✓`, 중단은 노란색 `■`, 실패는 빨간색 `×`로 구분하며, 완료·중단·실패는 이벤트 발생 후 5초 동안 표시한다. 같은 subagent에 후속 작업을 보내면 다시 실행 중으로 바뀐다. 도구 실행이나 메시지 갱신은 작업 상태를 변경하지 않는다. 출력이 없는 동안에도 종료 이벤트를 받기 전에는 실행 중 상태를 유지한다.

Codex의 subagent 기능으로 생성한 자식은 부모가 답변을 마친 뒤 백그라운드에서 계속 작업해도 감시한다. 셸에서 `codex exec ... &`로 직접 실행한 별도 세션은 이 부모·자식 연결에 포함되지 않는다.

[files/hooks.json](files/hooks.json)의 `SessionStart`, `SubagentStart`, `SubagentStop`, `SessionEnd` 훅이 Home Manager로 설치한 `~/.local/bin/codex-herdr-subagents`를 호출한다. 훅은 Herdr pane마다 감시 프로세스 하나를 실행하고, 감시 프로세스는 부모와 자식의 로컬 JSONL 기록을 읽어 `codex:herdr-subagents` metadata를 갱신한다. 부모 세션 종료나 Codex 프로세스 종료 시 표시를 지운다. Herdr 환경 변수가 없는 터미널에서는 실행하지 않는다.

실행 중인 자식의 기록을 읽지 못하거나 기록이 손상되면 회색 `○`와 마지막 메시지를 표시한다. 기록을 다시 읽어 작업 상태를 확인하면 정상 표시로 돌아간다. 감시 프로세스 자체가 종료되거나 Herdr에 전송할 수 없으면 새로운 상태를 표시할 수 없으므로 마지막 metadata가 15초 뒤 만료된다.

활동 줄은 최근 assistant 메시지의 공백과 제어 문자를 정리한 한 줄 발췌문이다. 별도의 모델 호출 없이 80자 이내로 표시하고, 길면 말줄임표를 붙인다. 도구 이벤트는 메시지를 덮어쓰지 않으며, 작업 완료 시 `last_agent_message`가 있으면 마지막 응답으로 갱신한다. 새 작업이 시작되면 이전 메시지를 지우고, 메시지가 없으면 활동 줄을 숨긴다. 고정 안내 문구는 영어이며 메시지는 원문 언어를 유지한다. Reasoning, 암호화된 메시지, 원시 명령어는 표시하지 않는다. 이 연동은 Codex CLI 0.155.1과 Herdr 0.9.1을 기준으로 검증했다. Codex의 내부 JSONL 형식은 안정된 API가 아니므로 CLI 업데이트 후 표시가 달라지면 실제 기록 형식과 parser를 확인한다.

부모의 정보 줄에는 `codex`와 부모 기록의 최근 `turn_context.model`만 표시한다. 첫 작업의 기록이 생기기 전에는 모델을 표시하지 않으며, 모델을 변경하면 다음 작업의 기록을 읽을 때 갱신한다. 자식 실행 수와 별도의 요약 문구는 표시하지 않는다.

감시 프로세스의 상태 파일은 쓰기와 탐색 권한이 있는 기존 `XDG_RUNTIME_DIR` 아래에 저장한다. 값이 없거나 절대 경로가 아니거나 해당 디렉터리를 사용할 수 없으면 시스템 임시 디렉터리를 사용한다. macOS에서 Linux용 `/run/user/<uid>` 값이 남아 있어도 해당 경로를 생성하지 않는다.

## 적용

Jev를 사용하는 기능은 `$typesafe-ai` skill로 설계하고, API client는 `with-jev`로 실행한다. 공식 skill 원본, agenix 인증, 적용 절차는 [Jev README](../jev/README.md)에서 확인한다.

Standalone Home Manager는 `/etc/codex/config.toml`을 checkout의 `files/config.toml`에 연결한다. NixOS는 같은 파일을 Nix store에서 설치한다. `~/.codex/config.toml`은 사용자 설정을 보존하며 activation이 덮어쓰지 않는다.

`~/.codex/AGENTS.md`와 `/etc/codex/skills`는 agent-core의 immutable output을 사용한다. Adapter 변경을 적용하려면 환경에 맞는 `home-manager switch --flake .#<environment>` 또는 `nixos-rebuild switch --flake .#<host>`를 사용자가 실행한 뒤 새 Codex 세션을 시작한다.

Herdr 연동도 같은 switch로 훅과 실행 파일을 설치한 뒤 `herdr server reload-config`를 실행하고 Herdr 안에서 새 Codex 세션을 시작한다. 실행 중인 Codex 세션에는 새 훅 설정이 자동 적용되지 않을 수 있다.
