# Hermes Agent 모듈

Hermes 관련 설정은 이 디렉터리 아래로 모읍니다.

## 파일 구성

- `default.nix` — Home Manager용 Hermes CLI/bootstrap 설정
- `system.nix` — NixOS용 Hermes gateway/service 설정
- `README.md` — 구조 설명

## 현재 역할

### `default.nix`
- `hermes` CLI 설치
- 기본 `HERMES_HOME` 설정
- 필요 시 `modules.hermes-agent.useServiceHome = true`로 `~/.hermes-service/.hermes`를 CLI 기본 홈으로 사용
- service home 사용 시 기존 `~/.hermes`는 백업 후 symlink로 정리
- 최초 1회 `config.yaml` seed
- 기본 디렉터리 생성 (`cron/`, `logs/`, `memories/`, `profiles/`, `sessions/`, `skills/`)
- 편의 alias 제공 (`hermes-setup`, `hermes-doctor`, `hermes-migrate-openclaw`)

### `system.nix`
- `pylv-onyx`에서 Hermes gateway/systemd service 활성화
- onyx에서는 CLI도 같은 service home을 기본 사용하도록 구성 가능
- `hermes-discord-bot-token.age`를 agenix로 복호화
- service state 디렉터리(`~/.hermes-service`) 관리
- Discord bot token을 service 시작 직전에 `.env`에 주입
- Discord 허용 유저/허용 채널 제한

## 규칙

- Hermes 관련 설정을 추가할 때는 먼저 `modules/hermes-agent/` 아래에 둘 수 있는지 확인
- host 파일에는 가능하면 import만 남기고, Hermes 구현 세부사항은 여기로 모읍니다
