# OpenClaw 모듈

`pylv-onyx` 기준으로 OpenClaw Gateway와 Control UI/API를 노출하는 설정입니다.

현재 운영 모드:
- **Nix는 OpenClaw 패키지 / seed config / secret-delivery bootstrap / nginx 프록시 / user-service PATH drop-in을 관리**
- **실제 OpenClaw gateway 서비스는 OpenClaw CLI가 설치한 user service가 관리**
- **시스템의 `openclaw` 명령은 하이브리드 wrapper이며, 실제 실행 파일은 `flake-stores`의 upstream npm 기반 `pkgs.openclaw`를 사용합니다**
- **Nix activation은 `~/.openclaw/openclaw.json`이 없을 때만 초기 config를 seed에서 생성하고, 기존 mutable user config는 덮어쓰지 않습니다.**

마지막 검증: `2026-05-18`

## 구성 요약

- OpenClaw Gateway 원본 프로세스는 user-managed OpenClaw service가 `127.0.0.1:18789`와 `[::1]:18789`에 바인딩하도록 기대합니다.
- OpenClaw seed config는 `/etc/openclaw/openclaw.seed.json`으로 Nix가 제공합니다.
- Secret bootstrap script는 `/etc/openclaw/bootstrap.sh`로 제공되며, OpenClaw wrapper만 이를 source합니다.
- Nix는 `~/.config/systemd/user/openclaw-gateway.service.d/20-nix-path.conf` drop-in을 설치해 NixOS용 PATH를 보정합니다.
- Mutable runtime config는 `~/.openclaw/openclaw.json`을 사용합니다.
- Nix는 기존 `~/.openclaw/openclaw.json` 내용을 재작성하지 않고, 파일이 없을 때만 seed + gateway token으로 초기 config를 생성합니다.
- OpenClaw Control UI 및 OpenAI 호환 API는 gateway bearer token을 주입하는 `nginx` 프록시를 통해 LAN용 `0.0.0.0:18790`과 Cloudflare Tunnel origin용 `127.0.0.1:18791`으로 노출됩니다.
- LAN용 `18790` 포트는 NixOS 방화벽에서 `wlo1` 인터페이스에만 열려 있습니다.
- 공개 오리진 `18791`은 loopback only라서 host 밖에서 직접 접근되지 않습니다.
- OpenClaw는 `gateway.tailscale.mode = "off"`라서 Tailscale Serve로 직접 노출되지 않습니다.
- Discord thread binding은 유지하되, **ACP의 Discord child-thread 자동 spawn은 비활성화**합니다.

## Discord + Codex/ACP 운영 규칙

- 기본 원칙은 **"target thread를 먼저 정하고, 거기에 bind"** 입니다.
- Discord에서 persistent Codex/ACP 작업이 필요하면, 먼저 작업할 thread를 열거나 선택한 뒤 `'/acp spawn codex --bind here'`를 사용합니다.
- 기존 Discord thread 안에서는 ACP를 새 child thread로 spawn하지 않습니다.
- 이 구성은 `channels.discord.threadBindings.spawnAcpSessions = false`로 seed에 박아 둡니다.
- 대신 일반 thread binding 자체와 native subagent thread session은 유지합니다.
- top-level channel에서 새 Codex 작업 공간이 필요하면, OpenClaw가 child thread를 자동 생성하게 두는 대신 **직접 thread를 만들고 그곳에서 bind here** 하는 운영을 기본값으로 삼습니다.
- `thread: true` 기반 ACP child-thread 생성은 upstream parity가 맞아진 뒤 다시 검토합니다.

## 접근 방법

### OpenClaw Control UI / API

- LAN에서 접속: `http://pylv-onyx:18790`
- LAN 이름 해석이 안 되면: `http://192.168.0.10:18790`
- Tailscale에서는 현재 직접 접속 불가
- Cloudflare Tunnel origin: `http://127.0.0.1:18791`

직접 접속이 안 되는 이유:

- OpenClaw 원본 게이트웨이는 loopback 전용입니다.
- LAN용 프록시 `18790`은 방화벽 규칙상 `wlo1`에만 열려 있어서 Tailscale 인터페이스에서는 허용되지 않습니다.
- Cloudflare 공개 경로는 별도 loopback 오리진 `18791`을 쓰므로, LAN 노출 규칙과 분리됩니다.
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
systemctl --user daemon-reload
openclaw gateway restart
```

주의:
- 이 모드는 system-level `openclaw-gateway.service`가 아니라 OpenClaw CLI가 설치한 user service를 기준으로 한다.
- Nix가 설치하는 `openclaw` 명령은 `/etc/openclaw/bootstrap.sh`와 NixOS PATH 보정을 먼저 적용한 뒤, `flake-stores`의 upstream npm 기반 `pkgs.openclaw` wrapper를 실행한다.
- Discord bot token, Brave API key 같은 secret은 `/run/agenix/*`에 두고, `/etc/openclaw/bootstrap.sh`를 OpenClaw wrapper만 source해서 process env로 주입한다.
- 따라서 login shell 전체에 secret을 export하지 않는다.
- `OPENCLAW_CONFIG_PATH` / `OPENCLAW_STATE_DIR`는 host session variables로 고정되어 있다.
- Gateway token의 source of truth는 기존 `~/.openclaw/openclaw.json`이 있으면 그 파일이고, config가 없을 때는 token file/랜덤 토큰을 기반으로 초기 config를 만든다.
- 그래서 seed를 바꾼 뒤에도 기존 `~/.openclaw/openclaw.json`은 자동으로 덮어쓰지 않는다. 이미 생성된 mutable config는 별도 patch/restart가 필요하다.

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
