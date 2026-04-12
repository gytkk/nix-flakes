# OpenClaw 모듈

`pylv-onyx` 기준으로 OpenClaw Gateway와 Open WebUI를 함께 노출하는 설정입니다.

마지막 검증: `2026-04-12`

## 구성 요약

- OpenClaw Gateway 원본 서비스는 `127.0.0.1:18789`와 `[::1]:18789`에만 바인딩됩니다.
- OpenClaw Control UI 및 OpenAI 호환 API는 `nginx` 프록시를 통해 `0.0.0.0:18790`으로 노출됩니다.
- 이 `18790` 포트는 NixOS 방화벽에서 `wlo1` 인터페이스에만 열려 있습니다.
- Open WebUI 원본 서비스는 `127.0.0.1:8081`에만 바인딩됩니다.
- `nginx` 프론트 프록시가 `0.0.0.0:8080`에서 Open WebUI를 노출하고, 고정 trusted-auth 헤더를 주입합니다.
- Tailscale Serve는 `https://pylv-onyx.tailbbb9bf.ts.net:8444`를 `127.0.0.1:8080`으로 프록시합니다.
- OpenClaw는 `gateway.tailscale.mode = "off"`라서 Tailscale Serve로 직접 노출되지 않습니다.

## 접근 방법

### Open WebUI

- Tailscale에서 바로 접속: `https://pylv-onyx.tailbbb9bf.ts.net:8444/`
- LAN에서 접속: `http://pylv-onyx:8080`
- LAN 이름 해석이 안 되면: `http://192.168.0.10:8080`
- 위 세 경로는 모두 `gytk.kim@gmail.com` 사용자로 자동 로그인됩니다.

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

### Open WebUI 로컬 터널 대안

Tailscale URL 대신 로컬 포워딩을 쓰고 싶다면:

```bash
ssh -N -L 3000:127.0.0.1:8080 gytkk@pylv-onyx
```

그 다음 브라우저에서:

```text
http://localhost:3000
```

## 인증 모델

- Open WebUI의 노출 경로(`8080`, `8444`, `localhost:3000`)는 `nginx` trusted-header 프록시 뒤에 있습니다.
- 그래서 브라우저에서는 이메일/비밀번호를 묻지 않고, 항상 `gytk.kim@gmail.com` 사용자로 자동 로그인됩니다.
- 반대로 raw 백엔드 `127.0.0.1:8081`은 trusted header 없이는 로그인 요청을 거부합니다.
- OpenClaw `18790` 경로는 `trusted-proxy` 헤더를 `nginx`가 주입하므로, 해당 포트에 도달한 클라이언트는 OpenClaw 관리자처럼 취급됩니다.
- 그래서 `18790`은 LAN 전용으로 제한되어 있습니다.

## 관련 설정 파일

- [`default.nix`](./default.nix)
- [`open-webui.nix`](../../hosts/pylv-onyx/open-webui.nix)
- [`configuration.nix`](../../hosts/pylv-onyx/configuration.nix)

## 검증에 사용한 명령

```bash
systemctl is-active open-webui.service tailscale-serve-open-webui.service openclaw-gateway.service nginx.service

tailscale serve status --json

ss -ltn | rg ':8080|:8081|:8444|:18789|:18790'

curl --silent --show-error --output /dev/null --write-out '%{http_code} %{url_effective}\n' \
  http://127.0.0.1:8080/

curl --silent --show-error --output /dev/null --write-out '%{http_code} %{url_effective}\n' \
  http://127.0.0.1:8081/

curl --silent --show-error --output /dev/null --write-out '%{http_code} %{url_effective}\n' \
  http://127.0.0.1:18790/health

curl --silent --show-error --output /dev/null --write-out '%{http_code} %{url_effective}\n' \
  https://pylv-onyx.tailbbb9bf.ts.net:8444/

curl -sS -H 'Content-Type: application/json' \
  -d '{"email":"ignored@example.com","password":"ignored"}' \
  http://127.0.0.1:8080/api/v1/auths/signin
```
