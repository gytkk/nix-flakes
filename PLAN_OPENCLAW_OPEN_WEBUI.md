# pylv-onyx

Open WebUI and OpenClaw are now wired together declaratively on `pylv-onyx`.

Last verified on `2026-04-12` from a shell on `pylv-onyx`.

## Verified working

- `open-webui.service` is active.
- `nginx.service` is active.
- `tailscale-serve-open-webui.service` is active.
- `openclaw-gateway.service` is active.
- Open WebUI frontend responds on `http://127.0.0.1:8080/`, the current LAN address `http://192.168.0.10:8080/`, and the Tailscale URL `https://pylv-onyx.tailbbb9bf.ts.net:8444/`.
- The raw Open WebUI backend responds on `http://127.0.0.1:8081/`.
- OpenClaw Control UI responds on the current LAN proxy address `http://192.168.0.10:18790/`.
- A real `POST /api/v1/auths/signin` request sent through `http://127.0.0.1:8080` returned the fixed admin user `gytk.kim@gmail.com` even with ignored credentials in the body.
- A real `POST /api/v1/auths/signin` request sent directly to `http://127.0.0.1:8081` failed with `Your provider has not provided a trusted header`.
- Open WebUI exposes `openclaw/main` from its own `/api/models` endpoint.
- Open WebUI is configured to expose both `openclaw/main` and `openclaw/pro`, and seeds per-agent model metadata so each can carry its own icon.
- A real `POST /openai/chat/completions` request sent to Open WebUI returned a successful response from OpenClaw.
- A real unauthenticated `POST /v1/chat/completions` request sent through the LAN OpenClaw proxy returned a successful response from OpenClaw.
- A real unauthenticated `openclaw status` call to `ws://127.0.0.1:18790` succeeded, while the raw gateway at `ws://127.0.0.1:18789` still rejected the same call with `unauthorized`.
- A WebSocket upgrade with `Origin: http://192.168.0.10:18790` succeeded against the LAN OpenClaw proxy.
- `openclaw dashboard --no-open` now prints the bare local Control UI URL `http://127.0.0.1:18789/` instead of a `#token=...` URL because LAN access uses trusted-proxy auth and the runtime config lives at `~/.openclaw/openclaw.json`.

## Current design

### Open WebUI

- [`hosts/pylv-onyx/open-webui.nix`](./hosts/pylv-onyx/open-webui.nix) keeps the raw Open WebUI service on loopback `127.0.0.1:8081`.
- An `nginx` frontend listens on `0.0.0.0:8080`, but the NixOS firewall only allows that port on interface `wlo1`.
- That frontend injects `x-open-webui-email: gytk.kim@gmail.com` and `x-open-webui-name: gytkk`, so LAN, Tailscale, and SSH-tunneled clients are auto-signed in as the same Open WebUI admin.
- `ENABLE_LOGIN_FORM = false` hides the browser login form on the exposed path, while the raw backend still requires the trusted header.
- Tailscale Serve now proxies to the `nginx` frontend on `127.0.0.1:8080`, so trusted-header auth also applies on the Tailscale URL.
- The OpenAI-compatible backend points at `http://127.0.0.1:18790/v1`, which is the local trusted-proxy path into OpenClaw.
- `ENABLE_EVALUATION_ARENA_MODELS` is disabled so the UI only shows the real OpenClaw model.

### Why the config seed exists

Current OpenClaw `2026.3.8` exposes `POST /v1/chat/completions`, but it does not expose `GET /v1/models`.

Open WebUI `0.8.10` can work around that, but only if `openai.api_configs.<idx>.model_ids` is present in its persistent config. In this version, `OPENAI_API_CONFIGS` is not read from environment variables, so [`hosts/pylv-onyx/open-webui.nix`](./hosts/pylv-onyx/open-webui.nix) seeds `/var/lib/open-webui/data/config.json` during `preStart` on every boot with:

```json
{
  "version": 0,
  "ui": {},
  "openai": {
    "api_configs": {
      "0": {
        "enable": true,
        "model_ids": [
          "openclaw/main"
        ]
      }
    }
  }
}
```

That keeps the runtime declarative even though Open WebUI stores the value in its SQLite config table at startup.

Additionally, `open-webui-openclaw-model-metadata.service` signs into the trusted local frontend after boot and upserts Open WebUI model metadata overrides for `openclaw/main` and `openclaw/pro`. Those overrides keep the OpenClaw model IDs intact while attaching per-agent icons via `meta.profile_image_url`, so the model picker can show a distinct badge for each agent.

### OpenClaw

- [`modules/openclaw/default.nix`](./modules/openclaw/default.nix) enables `gateway.http.endpoints.chatCompletions`.
- The gateway itself stays on loopback `127.0.0.1:18789`.
- `gateway.auth.mode = "trusted-proxy"` is enabled, so the gateway only trusts requests that come from loopback proxy IPs and include the injected proxy headers.
- A local-network `nginx` reverse proxy listens on `0.0.0.0:18790`, but the firewall only allows that port on interface `wlo1`.
- That proxy injects `x-openclaw-user: lan-admin` and `x-openclaw-proxy: 1`, which intentionally makes any LAN client on `18790` an OpenClaw admin/operator.
- `gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback = true` is enabled so the Control UI WebSocket handshake works whether LAN clients open the proxy via hostname or IP.
- OpenClaw Tailscale Serve is disabled because OpenClaw `trusted-proxy` auth is incompatible with `gateway.tailscale.mode = "serve"`.
- Nix seeds `/etc/openclaw/openclaw.seed.json` and `/etc/openclaw/openclaw.guardrails.json`, but the service and CLI both read the mutable runtime file `~/.openclaw/openclaw.json`.
- [`hosts/pylv-onyx/configuration.nix`](./hosts/pylv-onyx/configuration.nix) exports `OPENCLAW_CONFIG_PATH` and `CLAWDBOT_CONFIG_PATH` to that runtime file path for login shells.
- `openclaw-gateway.service` bootstraps `~/.openclaw/openclaw.json` from the seed on first start, migrates the old symlink if present, and deep-merges guardrails back into the runtime file on every restart.

## Access

### Tailscale

Use:

```text
https://pylv-onyx.tailbbb9bf.ts.net:8444/
```

### Local network

Use:

```text
http://pylv-onyx:8080
```

If local name resolution does not work on a client, use the current Wi-Fi address instead:

```text
http://192.168.0.10:8080
```

### OpenClaw Control UI on the local network

Use:

```text
http://pylv-onyx:18790
```

If local name resolution does not work on a client, use:

```text
http://192.168.0.10:18790
```

Authentication note:

- The Control UI is intentionally tokenless on the LAN URL.
- Open `http://pylv-onyx:18790` or `http://192.168.0.10:18790` directly.
- If you run `openclaw dashboard --no-open` on `pylv-onyx`, it now prints the bare local URL `http://127.0.0.1:18789/`; for another LAN client, just replace host and port with the LAN proxy URL.

### SSH tunnel

Use:

```bash
ssh -N -L 3000:127.0.0.1:8080 gytkk@pylv-onyx
```

Then open:

```text
http://localhost:3000
```

Authentication note:

- `http://localhost:3000` goes through the same trusted-header `nginx` frontend as LAN and Tailscale.
- The exposed path therefore auto-signs in as `gytk.kim@gmail.com`.
- Do not tunnel directly to `127.0.0.1:8081` unless you intentionally want the raw backend that requires trusted headers.

## Useful verification commands

```bash
systemctl is-active open-webui.service tailscale-serve-open-webui.service openclaw-gateway.service

ls -l ~/.openclaw/openclaw.json /etc/openclaw/openclaw.seed.json /etc/openclaw/openclaw.guardrails.json

ss -ltn | rg ':8080|:8081|:8444|:18789|:18790'

curl -sS -H 'Content-Type: application/json' \
  -d '{"email":"ignored@example.com","password":"ignored"}' \
  http://127.0.0.1:8080/api/v1/auths/signin

curl -sS -H 'Content-Type: application/json' \
  -d '{"email":"ignored@example.com","password":"ignored"}' \
  http://127.0.0.1:8081/api/v1/auths/signin

curl -sS -H 'Authorization: Bearer <open-webui-jwt>' \
  -H 'Content-Type: application/json' \
  -d '{"model":"openclaw/main","messages":[{"role":"user","content":"Reply with the single word OK."}],"stream":false}' \
  http://127.0.0.1:8080/openai/chat/completions

curl -sS http://192.168.0.10:18790/health

curl -sS -H 'Content-Type: application/json' \
  -d '{"model":"openclaw/main","messages":[{"role":"user","content":"Reply with the single word OK."}]}' \
  http://192.168.0.10:18790/v1/chat/completions

env -u OPENCLAW_GATEWAY_TOKEN -u CLAWDBOT_GATEWAY_TOKEN \
  OPENCLAW_GATEWAY_URL=ws://127.0.0.1:18790 \
  openclaw status
```
