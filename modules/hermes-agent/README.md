# Hermes Agent 모듈

Hermes 관련 설정은 이 디렉터리 아래로 모읍니다.

## 파일 구성

- `default.nix` — Home Manager용 최소 CLI 설정
- `system.nix` — NixOS용 최소 gateway/service 설정 (`pylv-onyx`)

## 현재 역할

### `default.nix`
- standalone Home Manager 환경에서만 `hermes` CLI와 `~/.hermes` bootstrap 제공
- NixOS에서 공식 `services.hermes-agent.addToSystemPackages = true`가 켜진 경우에는 충돌 방지를 위해 비활성화

### `system.nix`
- `pylv-onyx`에서 공식 upstream `services.hermes-agent` NixOS 모듈 사용
- `addToSystemPackages = true`로 CLI와 service가 `/var/lib/hermes/.hermes` 상태를 공유
- upstream cron 권한 모델 때문에 service는 `pylv-onyx`의 주 사용자로 실행해 CLI 접근을 유지
- `~/.codex/auth.json`을 Hermes auth seed로 사용
- raw Discord token agenix secret을 공식 `environmentFiles` 흐름에 맞는 env 파일로 변환
- `hermes-discord-bot-token.age`를 agenix로 복호화
- Discord bot token과 Discord gateway 제한값을 declarative config로 주입
- Discord 허용 유저/허용 채널 제한

원칙: 편의 기능보다 실제 동작에 필요한 최소 설정만 둡니다.
