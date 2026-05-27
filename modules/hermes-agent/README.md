# Hermes Agent

Minimal notes for reproducing the user-managed Hermes Agent install on NixOS.

## Prerequisites

- `git`, `curl`, `uv`, `nodejs`, `ripgrep`, and `ffmpeg` on `PATH`.
- `programs.nix-ld.enable = true` for upstream Linux binaries.
- A GitHub SSH key registered for the user.

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

## Update

```bash
hermes update
```
