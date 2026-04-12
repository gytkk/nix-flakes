# pylv-onyx

Open WebUI and OpenClaw are now wired together declaratively on `pylv-onyx`.

Last verified on `2026-04-12` from a shell on `pylv-onyx`.

## Verified working

- `open-webui.service` is active.
- `tailscale-serve-open-webui.service` is active.
- `openclaw-gateway.service` is active.
- Open WebUI responds on `http://127.0.0.1:8080/`.
- Tailscale Serve exposes Open WebUI on `https://pylv-onyx.tailbbb9bf.ts.net:8444/`.
- Password login works through both the Tailscale URL and an SSH tunnel to `http://localhost:3000`.
- Open WebUI exposes `openclaw/default` from its own `/api/models` endpoint.
- A real `POST /openai/chat/completions` request sent to Open WebUI returned a successful response from OpenClaw.

## Current design

### Open WebUI

- [`hosts/pylv-onyx/open-webui.nix`](./hosts/pylv-onyx/open-webui.nix) uses standard email/password login only.
- Trusted-header login was removed because Open WebUI `0.8.10` blocks localhost sign-in when `WEBUI_AUTH_TRUSTED_*` headers are required.
- The OpenAI-compatible backend points at `http://127.0.0.1:18789/v1` with the local gateway token.
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
          "openclaw/default"
        ]
      }
    }
  }
}
```

That keeps the runtime declarative even though Open WebUI stores the value in its SQLite config table at startup.

### OpenClaw

- [`hosts/pylv-onyx/openclaw.nix`](./hosts/pylv-onyx/openclaw.nix) enables `gateway.http.endpoints.chatCompletions`.
- The OpenClaw Control UI browser origin now matches the actual Tailscale Serve port: `8444`.

## Access

### Tailscale

Use:

```text
https://pylv-onyx.tailbbb9bf.ts.net:8444/
```

### SSH tunnel

Use:

```bash
ssh -N -L 3000:127.0.0.1:8080 gytkk@pylv-onyx
```

Then open:

```text
http://localhost:3000
```

## Useful verification commands

```bash
systemctl is-active open-webui.service tailscale-serve-open-webui.service openclaw-gateway.service

ss -ltn | rg ':8080|:8444|:18789'

curl -sS -H 'Authorization: Bearer <open-webui-jwt>' \
  http://127.0.0.1:8080/openai/config

curl -sS -H 'Authorization: Bearer <open-webui-jwt>' \
  http://127.0.0.1:8080/api/models

curl -sS -H 'Authorization: Bearer <open-webui-jwt>' \
  -H 'Content-Type: application/json' \
  -d '{"model":"openclaw/default","messages":[{"role":"user","content":"Reply with the single word OK."}],"stream":false}' \
  http://127.0.0.1:8080/openai/chat/completions
```
