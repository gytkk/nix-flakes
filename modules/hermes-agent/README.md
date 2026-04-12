# Hermes Agent 모듈

Hermes 관련 설정은 이 디렉터리 아래로 모읍니다.

## 파일 구성

- `default.nix` — Home Manager용 최소 CLI 설정
- `system.nix` — NixOS용 최소 gateway/service 설정 (`pylv-onyx`)

## 현재 역할

### `default.nix`
- `hermes` CLI 설치
- `HERMES_HOME`을 기본 경로인 `~/.hermes`로 설정
- 최초 1회 `~/.hermes/config.yaml`과 기본 디렉터리를 bootstrap

### `system.nix`
- `pylv-onyx`에서 Hermes gateway/systemd service 활성화
- systemd service를 명시적으로 `HERMES_HOME=~/.hermes`로 실행
- `hermes-discord-bot-token.age`를 agenix로 복호화
- Discord bot token을 service 시작 직전에 `.env`에 주입
- Discord 허용 유저/허용 채널 제한
- Hermes service state 디렉터리를 `~/.hermes` 하나로 통일

원칙: 편의 기능보다 실제 동작에 필요한 최소 설정만 둡니다.
