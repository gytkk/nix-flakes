# OpenClaw

OpenClaw is installed with the official rootless installer under `~/.openclaw`.
The application owns its executable, plugins, mutable configuration, state,
updates, and systemd user service.

This directory contains only declarative host integration:

- `default.nix` provides NixOS dependencies, the agenix Discord token, runtime
  environment variables, and proxy authentication.
- `nginx-proxy.nix` provides the LAN and public-origin reverse proxies and the
  LAN firewall rule.
- `home.nix` adds the user-owned executable to `PATH` and supplies the NixOS runtime paths required by the OpenClaw-managed user service. It can also install the rendered agent-core skills and context hook plus the repository-managed `agent-session-record` plugin.

The modules do not install an OpenClaw package, generate `openclaw.json`, set
`OPENCLAW_NIX_MODE`, or own `openclaw-gateway.service`.

## Agent-core integration

When `modules.openclaw.agentCore.enable` is true, Home Manager installs OpenClaw's shared skill render at `~/.openclaw/skills`, stores generated shared instructions at `~/.openclaw/managed/agent-core/AGENTS.core.md`, and installs the `agent-core-context` extension. The extension uses `before_prompt_build` to return `prependSystemContext`. It does not replace OpenClaw's system prompt or write a workspace `AGENTS.md`, so workspace instructions remain independently owned and are loaded through OpenClaw's normal bootstrap path.

The module does not edit mutable `openclaw.json`. Enable the hook there and grant the conversation access required by `before_prompt_build`:

```json
{
  "plugins": {
    "allow": ["agent-core-context", "agent-session-record"],
    "entries": {
      "agent-core-context": {
        "enabled": true,
        "hooks": {
          "allowConversationAccess": true
        }
      }
    }
  }
}
```

If `plugins.allow` already exists, merge these IDs into the existing list. Do not set `plugins.entries.agent-core-context.hooks.allowPromptInjection` to `false`. Restart the Gateway after changing plugin configuration or code.

After applying the Home Manager generation and restarting the Gateway, run the read-only smoke test:

```bash
modules/openclaw/tests/runtime-smoke.sh
```

The script checks the generated instruction file, plugin activation and diagnostics, the single `before_prompt_build` hook, managed skill discovery for every configured agent, and workspace precedence for duplicate skill names. It reports a skipped multi-workspace check when all configured agents share one workspace. Exact live prompt contents require a trajectory export and are not collected by this smoke test.

## Session recorder

The session recorder subscribes to OpenClaw's `session_end` plugin event and reads the transcript through OpenClaw 2.0's session identity API. It passes the returned events to `agent-session-record` without depending on an active transcript file path. It does not receive or upload the raw session key. If mutable OpenClaw configuration defines `plugins.allow`, include `agent-session-record` in that list.
