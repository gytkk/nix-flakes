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

When `modules.openclaw.agentCore.enable` is true, Home Manager installs OpenClaw's shared skill render at `~/.local/share/openclaw/agent-core/skills`, stores generated shared instructions at `~/.openclaw/managed/agent-core/AGENTS.core.md`, and installs the `agent-core-context` extension. Keeping the skill root outside mutable OpenClaw state prevents the Home Manager store symlink from entering state archives. The extension uses `before_prompt_build` to return `prependSystemContext`. It does not replace OpenClaw's system prompt or write a workspace `AGENTS.md`, so workspace instructions remain independently owned and are loaded through OpenClaw's normal bootstrap path.

The module does not edit mutable `openclaw.json`. Add the managed skill root to `skills.load.extraDirs`, enable the hook, and grant the conversation access required by `before_prompt_build`:

```json
{
  "skills": {
    "load": {
      "extraDirs": [
        "/home/gytkk/.local/share/openclaw/agent-core/skills"
      ]
    }
  },
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

If `skills.load.extraDirs` or `plugins.allow` already exists, merge the path or IDs into the existing lists. Do not set `plugins.entries.agent-core-context.hooks.allowPromptInjection` to `false`. Restart the Gateway after changing plugin configuration or code.

After applying the Home Manager generation and restarting the Gateway, run the read-only smoke test:

```bash
modules/openclaw/tests/runtime-smoke.sh
```

The script checks the generated instruction file, plugin activation and diagnostics, the single `before_prompt_build` hook, managed skill discovery for every configured agent, and workspace precedence for duplicate skill names. It reports a skipped multi-workspace check when all configured agents share one workspace. Exact live prompt contents require a trajectory export and are not collected by this smoke test.

After activation, confirm that Home Manager removed the old state-owned link and that the new root exists:

```bash
test ! -e ~/.openclaw/skills && test ! -L ~/.openclaw/skills
test -d ~/.local/share/openclaw/agent-core/skills
```

After updating `skills.load.extraDirs`, validating the config, and restarting the Gateway, create and verify a fresh archive outside the state and workspace trees:

```bash
openclaw config validate
mkdir -p ~/backups/openclaw
openclaw backup create --output ~/backups/openclaw --verify
```

The command prints the created archive path. Run `openclaw backup verify <archive-path>` for an independent repeat verification, then check `openclaw status --json | jq '.backups.latest'` for a recorded `status` of `success`.

## Session recorder

The session recorder subscribes to OpenClaw's `session_end` plugin event and reads the transcript through OpenClaw 2.0's session identity API. It passes the returned events to `agent-session-record` without depending on an active transcript file path. It does not receive or upload the raw session key. If mutable OpenClaw configuration defines `plugins.allow`, include `agent-session-record` in that list.
