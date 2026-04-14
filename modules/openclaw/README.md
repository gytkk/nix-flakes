# OpenClaw 모듈

`pylv-onyx` 기준으로 OpenClaw Gateway와 Control UI/API를 노출하는 설정입니다.

현재 운영 모드:
- **Nix는 OpenClaw 패키지 / seed config / secret-delivery bootstrap / nginx 프록시만 관리**
- **실제 OpenClaw gateway 서비스는 OpenClaw CLI가 설치한 user service가 관리**
- **시스템의 `openclaw` 명령은 하이브리드 wrapper라서 upstream의 `OPENCLAW_NIX_MODE=1` 기본값을 빈 값으로 덮어씀**
- **Nix activation은 `~/.openclaw/openclaw.json`이 없을 때만 초기 config를 seed에서 생성하고, 기존 mutable user config는 덮어쓰지 않습니다.**

마지막 검증: `2026-04-14`

## 구성 요약

- OpenClaw Gateway 원본 프로세스는 user-managed OpenClaw service가 `127.0.0.1:18789`와 `[::1]:18789`에 바인딩하도록 기대합니다.
- OpenClaw seed config는 `/etc/openclaw/openclaw.seed.json`으로 Nix가 제공합니다.
- Secret bootstrap script는 `/etc/openclaw/bootstrap.sh`로 제공되며, OpenClaw wrapper만 이를 source합니다.
- Mutable runtime config는 `~/.openclaw/openclaw.json`을 사용합니다.
- Nix는 기존 `~/.openclaw/openclaw.json` 내용을 재작성하지 않고, 파일이 없을 때만 seed + gateway token으로 초기 config를 생성합니다.
- OpenClaw Control UI 및 OpenAI 호환 API는 gateway bearer token을 주입하는 `nginx` 프록시를 통해 `0.0.0.0:18790`으로 노출됩니다.
- 이 `18790` 포트는 NixOS 방화벽에서 `wlo1` 인터페이스에만 열려 있습니다.
- OpenClaw는 `gateway.tailscale.mode = "off"`라서 Tailscale Serve로 직접 노출되지 않습니다.

## 접근 방법

### OpenClaw Control UI / API

- LAN에서 접속: `http://pylv-onyx:18790`
- LAN 이름 해석이 안 되면: `http://192.168.0.10:18790`
- Tailscale에서는 현재 직접 접속 불가

직접 접속이 안 되는 이유:

- OpenClaw 원본 게이트웨이는 loopback 전용입니다.
- 외부용 프록시 `18790`은 방화벽 규칙상 `wlo1`에만 열려 있어서 Tailscale 인터페이스에서는 허용되지 않습니다.
- 설정 파일 [`default.nix`](./default.nix) 에서 `gateway.tailscale.mode = "off"`를 명시하고 있습니다.

## Tailscale에서 OpenClaw를 써야 할 때

현재 구성에서는 Tailscale SSH 터널을 통해 접근하는 것이 맞습니다.

### OpenClaw Control UI 터널

```bash
ssh -N -L 18790:127.0.0.1:18790 gytkk@pylv-onyx
```

그 다음 브라우저에서:

```text
http://localhost:18790
```

## 인증 모델

- OpenClaw 원본 gateway `127.0.0.1:18789`는 token auth를 사용합니다.
- OpenClaw `18790` 경로는 `nginx`가 loopback gateway bearer token을 upstream에 주입하므로, 해당 포트에 도달한 클라이언트는 OpenClaw 관리자처럼 취급됩니다.
- 그래서 `18790`은 LAN 전용으로 제한되어 있습니다.

## user-managed gateway service bootstrap

NixOS rebuild 후 최초 1회 또는 service를 다시 만들고 싶을 때:

```bash
# 새 로그인 셸에서 실행 (DISCORD_BOT_TOKEN export 반영)
openclaw gateway install
openclaw gateway start
```

이미 user service가 있다면:

```bash
openclaw gateway restart
```

주의:
- 이 모드는 system-level `openclaw-gateway.service`가 아니라 OpenClaw CLI가 설치한 user service를 기준으로 한다.
- Nix가 설치하는 `openclaw` 명령은 내부적으로 upstream 패키지 wrapper의 `OPENCLAW_NIX_MODE=1` 기본값을 빈 값으로 덮어써 CLI-managed service 경로를 사용한다.
- Discord bot token, Brave API key 같은 secret은 `/run/agenix/*`에 두고, `/etc/openclaw/bootstrap.sh`를 OpenClaw wrapper만 source해서 process env로 주입한다.
- 따라서 login shell 전체에 secret을 export하지 않는다.
- `OPENCLAW_CONFIG_PATH` / `OPENCLAW_STATE_DIR`는 host session variables로 고정되어 있다.
- Gateway token의 source of truth는 기존 `~/.openclaw/openclaw.json`이 있으면 그 파일이고, config가 없을 때는 token file/랜덤 토큰을 기반으로 초기 config를 만든다.

## 관련 설정 파일

- [`default.nix`](./default.nix)
- [`configuration.nix`](../../hosts/pylv-onyx/configuration.nix)

## 검증에 사용한 명령

```bash
systemctl --user is-active openclaw-gateway.service
systemctl is-active nginx.service

ss -ltn | rg ':18789|:18790'

curl --silent --show-error --output /dev/null --write-out '%{http_code} %{url_effective}\n' \
  http://127.0.0.1:18790/health
```
