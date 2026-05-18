# OpenClaw Doctor Warnings

Generated from `openclaw doctor` on May 18, 2026.

## Current Gateway Status

- `openclaw-gateway.service` is active.
- `openclaw gateway status` reports `Connectivity probe: ok`.
- Gateway capability is `admin-capable`.
- Gateway version is `2026.5.12`.

## Remaining Warnings

### Personal Codex Assets

OpenClaw found personal Codex assets under:

- `/home/gytkk/.codex`
- `/home/gytkk/.agents/skills`

Native Codex-mode OpenClaw agents use isolated per-agent Codex homes, so these
assets are not loaded automatically.

### Discord Group Allowlist

`channels.discord.groupPolicy` is `allowlist`, but both `groupAllowFrom` and
`allowFrom` are empty.

Effect: Discord group messages can be silently dropped until allowed senders
are configured or the policy is changed to `open`.

### Command Owner

`commands.ownerAllowFrom` is not configured.

Effect: owner-only commands such as `/diagnostics`, `/export-trajectory`,
`/config`, and exec approvals do not have an explicit owner identity.

### State Integrity

Doctor found state that does not match the current config:

- One agent directory exists without a matching `agents.list` entry: `gpt-pro`.
- Nineteen orphan transcript files exist under
  `~/.openclaw/agents/main/sessions`.

Doctor says it can archive orphan transcripts by renaming them to
`*.deleted.<timestamp>`.

### Legacy Session Route State

Doctor found legacy `openai-codex/*` session route state.

- Affected sessions: `168`.
- `openclaw doctor --fix` can rewrite stale session model/provider pins across
  agent session stores.

### Skill Requirements

Doctor reports:

- Eligible skills: `23`
- Missing requirements: `38`
- Blocked by allowlist: `0`

Most listed skills are unusable because they are macOS-only, missing binaries,
or require missing environment variables/configuration.

## Clean Sections

- Gateway service is healthy.
- Browser warnings are gone.
- Security warnings are clear.
- External plugin warnings are gone.
- Stale plugin reference warnings are gone.
- Plugin load errors are `0`.
- Loaded plugins: `68`.

## Notes

The remaining warnings mostly require explicit decisions: choosing Discord
sender allowlists, setting a command owner, and allowing
`openclaw doctor --fix` to rewrite state files.
