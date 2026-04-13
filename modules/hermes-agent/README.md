# Hermes Agent 모듈

Hermes 관련 설정은 이 디렉터리 아래로 모읍니다.

## 파일 구성

- `default.nix` — Home Manager용 최소 CLI 설정
- `system.nix` — NixOS용 managed gateway/service 설정 템플릿

## 현재 역할

### `default.nix`
- Home Manager 환경에서 `hermes` CLI와 `~/.hermes` bootstrap 제공
- `package.nix`의 patched Hermes package를 사용해 one-half-light skin 보정 적용
- bundled skills sync 뒤 local `~/.hermes/skills` tree를 writable로 정규화하는 patched Hermes package 사용
- `NO_COLOR`가 잡힌 셸에서도 prompt_toolkit 색이 꺼지지 않도록 wrapper에서 보정
- NixOS에서 공식 `services.hermes-agent.addToSystemPackages = true`가 켜진 경우에만 `HERMES_HOME`을 system state dir로 맞춤

### `system.nix`
- 현재 `pylv-onyx`의 Hermes CLI runtime path와는 분리된, system-managed gateway 템플릿
- upstream `services.hermes-agent` 기반으로 `/var/lib/hermes/.hermes` 상태를 관리할 때 사용
- `~/.codex/auth.json`을 Hermes auth seed로 사용
- `one-half-light` custom skin을 `/var/lib/hermes/.hermes/skins/`에 설치하고 기본 skin으로 고정
- inline diff add/remove colors, input prompt, `@` context picker completion menu colors를 light palette로 오버라이드
- Hermes bundled skill sync 뒤 local skill tree를 writable로 정규화하는 patched package 사용
- `hermes-discord-bot-token.age`를 agenix로 복호화
- Discord bot token은 서비스 시작 전 writable `~/.hermes/.env`로 동기화
- Discord 허용 유저/허용 채널/mention 제약값은 최초 한 번만 seed하고 이후에는 Hermes가 직접 수정 가능
- 더 이상 upstream `environment/environmentFiles`로 `.env`를 매 rebuild마다 덮어쓰지 않음
- 서비스 시작 전 기존 `~/.hermes/skills` tree도 writable 권한으로 정규화

원칙: 편의 기능보다 실제 동작에 필요한 최소 설정만 둡니다.

## Hermes WebUI 엔드포인트

`pylv-onyx`에서 Hermes WebUI 접속:

- **LAN**: `http://192.168.0.10:8787/` (`wlo1` 인터페이스)
- **Tailscale**: `https://pylv-onyx.tailbbb9bf.ts.net:8445/` 또는 `http://pylv-onyx:8787/`
- **Backend**: `127.0.0.1:8788` (loopback 전용)
