# Hermes 모듈

`hermes-agent` flake input을 통해 Hermes CLI를 Home Manager로 설치합니다.

## 제공 내용

- `hermes` / `hermes-agent` / `hermes-acp` 바이너리 설치
- `HERMES_HOME=~/.hermes` 세션 변수 설정
- 최초 1회 `~/.hermes/config.yaml`을 upstream example로 시드
- `~/.hermes/.env`, `cron/`, `logs/`, `memories/`, `profiles/`, `sessions/`, `skills/` 기본 디렉터리 생성
- 편의 alias:
  - `hermes-setup`
  - `hermes-doctor`
  - `hermes-migrate-openclaw`

## 첫 사용

```bash
hermes setup
# 또는 기존 OpenClaw 상태를 가져오려면
hermes claw migrate
```

메시징 gateway/systemd 서비스는 아직 선언적으로 켜지지 않습니다. 먼저 CLI/로컬 상태를 안정적으로 쓰는 데 집중하고, 토큰/모델 키 정책이 정리되면 `services.hermes-agent`를 호스트별로 추가하면 됩니다.
