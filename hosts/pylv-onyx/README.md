# pylv-onyx

NixOS configuration for `pylv-onyx`, managed from the main flake.

## Open WebUI Status

Last verified on `2026-04-11` from an SSH session on `pylv-onyx`.

### Verified working

- `open-webui.service` is enabled and active.
- `tailscale-serve-open-webui.service` is enabled and active.
- `openclaw-gateway.service` is enabled and active.
- Open WebUI responds on `http://127.0.0.1:8080/`.
- Tailscale Serve exposes Open WebUI on `https://pylv-onyx.tailbbb9bf.ts.net:8444/`.
- OpenClaw Control UI responds on `http://127.0.0.1:18789/`.
- Open WebUI completed first-run migrations and created the admin account from environment variables.

### Confirmed problems

#### 1. SSH tunnel and localhost login are currently broken

The current Open WebUI configuration in [`open-webui.nix`](./open-webui.nix) enables both:

- `ENABLE_LOGIN_FORM = "true"`
- `WEBUI_AUTH_TRUSTED_EMAIL_HEADER = "Tailscale-User-Login"`

On Open WebUI `0.8.10`, these do not work together the way the current comments imply. When `WEBUI_AUTH_TRUSTED_EMAIL_HEADER` is set, the `/api/v1/auths/signin` endpoint requires that header on every sign-in request. A plain localhost request from an SSH tunnel does not provide it, so password login fails.

Observed error:

```json
{"detail":"Your provider has not provided a trusted header. Please contact your administrator for assistance."}
```

Result:

- `ssh -N -L 3000:127.0.0.1:8080 gytkk@pylv-onyx` opens the UI
- but logging in through `http://localhost:3000` does not work yet

#### 2. Open WebUI does not appear to be connected to a model backend yet

The Open WebUI database exists at `/var/lib/open-webui/data/webui.db`, but the persisted config only contained top-level keys:

- `ui`
- `version`

There was no persisted `openai` or `ollama` provider config, and the `model` table was empty at verification time.

Result:

- the web app is reachable
- but it should not be considered ready for real chat usage until a backend is configured and verified

#### 3. There is a port mismatch in the OpenClaw browser-origin settings

[`openclaw.nix`](./openclaw.nix) currently allows:

- `https://pylv-onyx.tailbbb9bf.ts.net:8443`

But Open WebUI is actually exposed on:

- `https://pylv-onyx.tailbbb9bf.ts.net:8444`

This mismatch does not block the Open WebUI landing page itself, but it is a risk if browser-origin checks matter during OpenClaw integration.

## Recommended next step

If local SSH tunnel login is the priority, the simplest fix is:

1. Remove `WEBUI_AUTH_TRUSTED_EMAIL_HEADER` and `WEBUI_AUTH_TRUSTED_NAME_HEADER` from [`open-webui.nix`](./open-webui.nix).
2. Rebuild and restart the host configuration.
3. Verify that password login works through `http://localhost:3000`.

Tradeoff:

- Tailscale users will also use the standard email/password login form.
- Automatic trusted-header login through Tailscale Serve will no longer be active.

This is the right direction if the goal is "SSH tunnel and local login first."

## Follow-up work after login is fixed

After the login path works, the remaining work is:

1. Configure Open WebUI to use OpenClaw as its backend.
2. Verify that models appear in the UI.
3. Send one real test prompt through the UI.
4. Reconcile the `8443` vs `8444` origin mismatch if browser-origin checks become relevant.

## How to access the service today

### Tailscale

Use:

```text
https://pylv-onyx.tailbbb9bf.ts.net:8444/
```

Current state:

- the URL is reachable
- HTTPS is working
- the app loads
- but backend configuration is still incomplete

### SSH tunnel from a LAN machine

Use:

```bash
ssh -N -L 3000:127.0.0.1:8080 gytkk@pylv-onyx
```

Then open:

```text
http://localhost:3000
```

Current state:

- the page loads
- password login is blocked by the trusted-header setting described above

## What you need to decide later

When you return to this work, the main decision is:

- keep trusted-header login for Tailscale and give up localhost password login
- or remove trusted-header login and standardize on email/password login for both Tailscale and SSH tunnel access

For the stated priority of "SSH tunnel and local login first", the second option is the recommended one.

## Useful verification commands

```bash
systemctl is-active open-webui.service tailscale-serve-open-webui.service openclaw-gateway.service

ss -ltn | rg ':8080|:8444|:18789'

curl -I http://127.0.0.1:8080/

curl -kvI --resolve pylv-onyx.tailbbb9bf.ts.net:8444:100.84.249.30 \
  https://pylv-onyx.tailbbb9bf.ts.net:8444/

journalctl -u open-webui.service -n 60 --no-pager
```
