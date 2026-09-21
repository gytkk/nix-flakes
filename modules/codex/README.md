# Codex

`files/config.toml`은 Codex의 기본 모델과 effort, MCP, 기능 설정을 관리한다. 메인 에이전트는 `gpt-6-astra`와 `medium` effort를 사용하며, worker의 기본값은 `gpt-5.6-sol`과 `medium`이다. 세션이나 사용자 설정에서 이 값을 덮어쓸 수 있다.

## 모델별 위임

[Codex adapter](../../agent-core/adapters/codex.md)는 독립적인 작업을 일찍 위임하고, worker를 생성할 때 작업 성격에 맞는 모델과 effort를 명시하도록 지시한다. 메인 에이전트는 사용자와의 대화, 요구사항 해석, 의사결정, 결과 통합과 최종 검증을 담당한다. 모델별 작업 범위와 재위임 기준은 adapter에서 관리한다.

이 동작은 에이전트가 따르는 위임 지침이며, 프롬프트의 복잡도를 계산해 모델을 강제로 선택하는 별도 라우터는 없다. Worker의 모델과 effort 선택은 메인 세션의 모델과 effort를 변경하지 않는다. 생성된 지침과 shared skill의 구조는 [Agent core README](../../agent-core/README.md)에서 확인한다.

## 적용

Standalone Home Manager는 `/etc/codex/config.toml`을 checkout의 `files/config.toml`에 연결한다. NixOS는 같은 파일을 Nix store에서 설치한다. `~/.codex/config.toml`은 사용자 설정을 보존하며 activation이 덮어쓰지 않는다.

`~/.codex/AGENTS.md`와 `/etc/codex/skills`는 agent-core의 immutable output을 사용한다. Adapter 변경을 적용하려면 환경에 맞는 `home-manager switch --flake .#<environment>` 또는 `nixos-rebuild switch --flake .#<host>`를 사용자가 실행한 뒤 새 Codex 세션을 시작한다.
