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

### Skill Requirements

Doctor reports:

- Eligible skills: `23`
- Missing requirements: `0`
- Blocked by allowlist: `0`

Previously unusable skills were disabled by `openclaw doctor --fix`.

## Clean Sections

- Gateway service is healthy.
- Browser warnings are gone.
- Security warnings are clear.
- External plugin warnings are gone.
- Stale plugin reference warnings are gone.
- State integrity warnings are gone.
- Legacy session route warnings are gone.
- Plugin load errors are `0`.
- Loaded plugins: `68`.

## Notes

The remaining warnings require explicit decisions: choosing Discord sender
allowlists, setting a command owner, and deciding whether to migrate personal
Codex assets into OpenClaw.
