# Jev

Codex와 Claude는 TypeSafe의 공식 `typesafe-ai` skill을 공유한다. Skill은 Jev의 typed decision을 활용하는 기능 설계와 API 사용법을 안내하며, 모델이나 MCP server를 설치하지 않는다. [공식 설치 문서](https://docs.typesafe.ai/agent-skill)와 [API 문서](https://docs.typesafe.ai/api)가 사용법의 기준이다.

## Skill 원본

Canonical source는 [agent-core/skills/typesafe-ai](../../agent-core/skills/typesafe-ai/)다. 공식 [typesafe-ai/skills v0.5.7](https://github.com/typesafe-ai/skills/tree/65a39f393687675ce170e6094757de20370365b9)의 `SKILL.md`와 MIT license를 보관하며, `SKILL.md`에는 로컬 API 키 전달 방법을 설명하는 `Local API access` 절만 추가한다. Upstream 지침은 현재 공식 문서를 확인하도록 요구한다.

[Manifest](../../agent-core/manifest.toml)는 이 skill을 Codex와 Claude에만 노출한다. 기존 renderer가 Codex의 `/etc/codex/skills/typesafe-ai`와 Claude의 `~/.claude/skills/typesafe-ai`에 설치할 immutable tree를 생성한다. 별도 marketplace 설치는 필요하지 않다.

업데이트할 때는 공식 revision의 skill과 license를 함께 확인하고, 로컬 API access 절을 보존하며 revision을 갱신한다. 변경을 검토한 뒤 agent-core의 두 golden hash 파일을 갱신하고 렌더링 검사를 실행한다.

## API 키

`modules.jev.enable`은 Codex 또는 Claude가 활성화된 환경에서 기본으로 켜진다. Home Manager는 `secrets/jev-api-key.age`를 agenix로 복호화하고, NixOS에서는 시스템 agenix가 사용자 소유의 `/run/agenix/jev-api-key`를 제공한다. 파일 권한은 `0400`이다. macOS의 경로와 재시도 동작은 [agenix Darwin 모듈](../agenix-darwin/README.md)이 관리한다.

`with-jev COMMAND [ARG...]`는 실행 시 복호화된 파일을 읽고 해당 프로세스와 자식에게만 `TYPESAFE_API_KEY`를 전달한다. 기존 환경 변수보다 agenix 값을 우선하며, 키를 읽을 수 없거나 비어 있으면 명령을 실행하지 않는다. 키 값은 Nix store, skill, agent 설정, 전역 shell 환경에 저장하지 않는다. API client는 환경 변수를 직접 읽어 인증해야 한다.

```bash
with-jev uv run app.py
with-jev node app.mjs
```

SDK는 사용하는 프로젝트가 관리한다. 공식 Python SDK와 JavaScript SDK 모두 `TYPESAFE_API_KEY`를 지원한다. `with-jev`는 CLI, IDE, desktop agent가 실행하는 shell에서 공통으로 사용할 수 있으며, 부모 agent를 키가 설정된 shell에서 시작할 필요는 없다.

Home Manager의 identity는 `~/.ssh/id_ed25519`다. 특히 별도 recipient가 없는 `pylv-denim`에서는 관리자 identity를 사용해야 현재 암호문을 복호화할 수 있다. Recipient 변경은 [저장소 secret 절차](../../README.md#secrets-with-agenix-and-1password)를 따른다.

## 적용과 사용

사용자가 환경에 맞는 `home-manager switch --flake .#<environment>` 또는 `nixos-rebuild switch --flake .#<host>`를 실행한 뒤 새 agent 세션을 시작한다.

- Codex: `$typesafe-ai`를 지정하거나 Jev를 사용하는 기능 구현을 요청한다.
- Claude: `/typesafe-ai`를 지정하거나 같은 요청을 한다. Marketplace plugin이 아니므로 `/typesafe:typesafe-ai` 이름을 사용하지 않는다.

예: "typesafe-ai skill을 사용해서 Jev로 문의를 분류하는 코드를 작성하고, API 호출은 with-jev로 실행해줘."

## 검증

키 전달, 오류 처리, 인자와 종료 상태 보존은 실제 키나 네트워크 없이 검사한다.

```bash
uv run --no-project modules/jev/test_with_jev.py
uv run --project agent-core -m pytest agent-core/tests
uv run --project agent-core agent-core check
```
