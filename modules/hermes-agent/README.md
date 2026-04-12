# Hermes Agent 모듈

Hermes 관련 설정은 이 디렉터리 아래로 모읍니다.

## 파일 구성

- `default.nix` — Home Manager용 최소 CLI 설정
- `system.nix` — NixOS용 최소 gateway/service 설정 (`pylv-onyx`)

## 현재 역할

### `default.nix`
- standalone Home Manager 환경에서만 `hermes` CLI와 `~/.hermes` bootstrap 제공
- bundled skills sync 뒤 local `~/.hermes/skills` tree를 writable로 정규화하는 patched Hermes package 사용
- NixOS에서 공식 `services.hermes-agent.addToSystemPackages = true`가 켜진 경우에는 충돌 방지를 위해 비활성화

### `system.nix`
- `pylv-onyx`에서 공식 upstream `services.hermes-agent` NixOS 모듈 사용
- `addToSystemPackages = true`로 CLI와 service가 `/var/lib/hermes/.hermes` 상태를 공유
- upstream cron 권한 모델 때문에 service는 `pylv-onyx`의 주 사용자로 실행해 CLI 접근을 유지
- `~/.codex/auth.json`을 Hermes auth seed로 사용
- `one-half-light` custom skin을 `/var/lib/hermes/.hermes/skins/`에 설치하고 기본 skin으로 고정
- inline diff add/remove colors도 `one-half-light` add/delete palette로 오버라이드
- Hermes bundled skill sync 뒤 local skill tree를 writable로 정규화하는 patched package 사용
- `hermes-discord-bot-token.age`를 agenix로 복호화
- Discord bot token은 서비스 시작 전 writable `~/.hermes/.env`로 동기화
- Discord 허용 유저/허용 채널/mention 제약값은 최초 한 번만 seed하고 이후에는 Hermes가 직접 수정 가능
- 더 이상 upstream `environment/environmentFiles`로 `.env`를 매 rebuild마다 덮어쓰지 않음
- 서비스 시작 전 기존 `~/.hermes/skills` tree도 writable 권한으로 정규화

원칙: 편의 기능보다 실제 동작에 필요한 최소 설정만 둡니다.
