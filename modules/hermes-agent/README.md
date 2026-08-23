# Hermes Agent

Minimal notes for reproducing the user-managed Hermes Agent install on NixOS.

## Prerequisites

- `git`, `curl`, `uv`, `nodejs`, `ripgrep`, and `ffmpeg` on `PATH`.
- `programs.nix-ld.enable = true` for upstream Linux binaries.
- A GitHub SSH key registered for the user.
- `SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt` in `~/.hermes/.env`.

## Install

Clone with the local SSH key directly if the forwarded SSH agent hangs:

```bash
mkdir -p ~/.hermes
GIT_SSH_COMMAND='ssh -o IdentityAgent=none -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519' \
  git clone git@github.com:NousResearch/hermes-agent.git ~/.hermes/hermes-agent
```

Run the local installer directly. Do not pipe the script output into `bash`.

```bash
cd ~/.hermes/hermes-agent
bash ./scripts/install.sh --skip-browser
```

`--skip-browser` avoids Playwright dependency setup during first bootstrap.
Configure browser support separately if Hermes browser workflows are needed.

## Discord Token

On hosts using this repo's agenix secret, the decrypted token is available at:

```bash
/run/agenix/discord-bot-token
```

For one-off Hermes runs:

```bash
export DISCORD_BOT_TOKEN="$(cat /run/agenix/discord-bot-token)"
```

## Discord Message Policy

Use this policy when Hermes should answer without mentions while keeping normal
channels thread-based:

```yaml
discord:
  require_mention: false
  free_response_channels: ''
  auto_thread: true
  thread_require_mention: false
```

Keep `free_response_channels` empty. Hermes treats those channels as inline
chat surfaces and skips auto-threading there.

## Update

```bash
hermes update
```

## Session record integration

The `pylv-onyx` Home Manager profile installs the
`agent-session-record` plugin under `~/.hermes/plugins/` and enables it with
Hermes's `plugins enable` command. The module does not manage `SOUL.md`,
`config.yaml`, memories, or local skills. The enable command only adds the
plugin name to Hermes's existing enabled plugin list.

Hermes v0.14.0 does not provide a `sessions export --redact` option. The
recorder therefore exports one session to a mode `0600` temporary file, removes
Discord routing fields, applies the common secret and personal data redaction,
and then deletes the temporary file. A malformed export or failed redaction is
not queued or uploaded for the Hermes provider. Claude and Codex retain their
existing redaction failure behavior.

After applying the Home Manager configuration and restarting the user-managed
gateway, verify the plugin and recorder configuration:

```bash
hermes plugins list
systemctl --user status hermes-gateway.service
```

Session archives are stored under
`/home/gytkk/agent-sessions/personal/hermes/<year>/<month>/<day>/` on Onyx.
