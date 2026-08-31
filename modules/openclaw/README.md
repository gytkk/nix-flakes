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

When `modules.openclaw.agentCore.enable` is true, Home Manager installs OpenClaw's shared skill render and generated instructions under `~/.local/share/openclaw/agent-core/`, and installs repository-managed extensions under `~/.local/share/openclaw/extensions/`. Keeping these immutable Home Manager store links outside mutable OpenClaw state prevents them from entering state archives. The `agent-core-context` extension uses `before_prompt_build` to return `prependSystemContext`. It does not replace OpenClaw's system prompt or write a workspace `AGENTS.md`, so workspace instructions remain independently owned and are loaded through OpenClaw's normal bootstrap path.

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
    "load": {
      "paths": [
        "/home/gytkk/.local/share/openclaw/extensions/agent-core-context",
        "/home/gytkk/.local/share/openclaw/extensions/agent-session-record"
      ]
    },
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

If `skills.load.extraDirs`, `plugins.load.paths`, or `plugins.allow` already exists, merge the paths or IDs into the existing lists. Do not set `plugins.entries.agent-core-context.hooks.allowPromptInjection` to `false`. Restart the Gateway after changing plugin configuration or code.

After applying the Home Manager generation and restarting the Gateway, run the read-only smoke test:

```bash
modules/openclaw/tests/runtime-smoke.sh
```

The script checks the generated instruction file, plugin activation and diagnostics, the single `before_prompt_build` hook, managed skill discovery for every configured agent, and workspace precedence for duplicate skill names. It reports a skipped multi-workspace check when all configured agents share one workspace. Exact live prompt contents require a trajectory export and are not collected by this smoke test.

After activation, confirm that Home Manager removed the old state-owned links and that the new roots exist:

```bash
for path in \
  ~/.openclaw/skills \
  ~/.openclaw/managed/agent-core/AGENTS.core.md \
  ~/.openclaw/extensions/agent-core-context \
  ~/.openclaw/extensions/agent-session-record; do
  test ! -e "$path" && test ! -L "$path"
done
test -s ~/.local/share/openclaw/agent-core/AGENTS.core.md
test -d ~/.local/share/openclaw/agent-core/skills
test -d ~/.local/share/openclaw/extensions/agent-core-context
test -d ~/.local/share/openclaw/extensions/agent-session-record
```

After updating `skills.load.extraDirs` and `plugins.load.paths`, validating the config, and restarting the Gateway, create and verify a fresh archive outside the state and workspace trees:

```bash
openclaw config validate
mkdir -p ~/backups/openclaw
openclaw backup create --output ~/backups/openclaw --verify
```

The command prints the created archive path. Run `openclaw backup verify <archive-path>` for an independent repeat verification, then check `openclaw status --json | jq '.backups.latest'` for a recorded `status` of `success`. A remaining failure at `~/.openclaw/codex-openclaw-home/auth.json` is separate legacy mutable state, not a Home Manager-owned integration resource; resolve that credential link before treating the archive as complete.

## Session recorder

The session recorder subscribes to OpenClaw's `session_end` plugin event and reads the transcript through OpenClaw 2.0's session identity API. It passes the returned events to `agent-session-record` without depending on an active transcript file path. It does not receive or upload the raw session key. If mutable OpenClaw configuration defines `plugins.allow`, include `agent-session-record` in that list.
