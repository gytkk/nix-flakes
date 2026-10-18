# OpenClaw

OpenClaw is installed with the official rootless installer under `~/.openclaw`.
The application owns its executable, plugins, mutable configuration, state,
updates, and systemd user service.

This directory contains only declarative host integration:

- `default.nix` provides NixOS dependencies, runtime
  environment variables, and proxy authentication.
- `nginx-proxy.nix` provides the LAN and public-origin reverse proxies and the
  LAN firewall rule.
- `home.nix` adds the user-owned executable to `PATH` and supplies the NixOS runtime paths required by the OpenClaw-managed user service. The systemd environment drop-in is materialized as a regular file because OpenClaw refuses update ownership checks when an effective service definition is a symlink. The module can also install rendered agent-core instructions and the context hook plus the repository-managed `agent-session-record` plugin.

The modules do not install an OpenClaw package, generate `openclaw.json`, set
`OPENCLAW_NIX_MODE`, or own `openclaw-gateway.service`.

Automation credentials belong to OpenClaw's local Secret Store. Discord uses a native `store` SecretRef named `DISCORD_BOT_TOKEN`; Nix does not provision its runtime token. The encrypted agenix source remains available for recovery. The Notion to Google Calendar automation uses protected `NOTION_CALENDAR_*` entries through OpenClaw's enabled secret egress proxy, restricted to the corresponding API hosts. Its model-free script job calls Gateway `exec` to receive the proxy context. Plain command jobs do not receive that context. The workspace automation README owns the runner configuration and key names.

The Secret Store protects disclosure through OpenClaw, but its local SQLite database is not encrypted at rest. Protect and back up OpenClaw's private state directory. Existing Brave and Gateway credentials remain native SecretRefs; GitHub CLI continues to own its OAuth login and Git credential helper.

The secret egress proxy requires OpenSSL in a trusted system directory. `default.nix` supplies it through `environment.systemPackages`, because OpenClaw's certificate generator does not search the user profile or `PATH`. After applying this module with `nixos-rebuild switch`, confirm `/run/current-system/sw/bin/openssl` exists and remove any temporary `/usr/bin/openssl` migration symlink.

## Public Control UI

The public URL is `https://claw.pylv.dev`. The Onyx Cloudflare Tunnel forwards this hostname directly to the loopback Gateway at `http://127.0.0.1:18789`. Cloudflare Access protects the hostname with the existing owner-email policy; OpenClaw separately requires its Gateway password and browser device pairing. The public route does not use the nginx bearer-token injection configured for the legacy proxy listeners.

The user-owned `openclaw-cloudflared.service` runs the connector independently of Nix and the Gateway service. Its private runtime directory is `~/.local/share/openclaw-cloudflared/`; `tunnel-token` is mode `0600`, and `package` is an indirect Nix GC root for its cloudflared runtime. User lingering keeps the service running after logout. Check it with `systemctl --user status openclaw-cloudflared.service` on Onyx. Update the runtime root explicitly when maintaining cloudflared; it is not upgraded by a Home Manager switch.

Mutable Gateway configuration keeps `gateway.bind` set to `loopback`, sets `gateway.publicOrigin` to `https://claw.pylv.dev`, and includes that exact HTTPS origin in `gateway.controlUi.allowedOrigins`. Preserve other allowed origins when editing the list. `gateway.trustedProxies` includes the loopback connector addresses so the Gateway can attribute Cloudflare's forwarded client IP. Keep password authentication and device checks enabled.

Use the authenticated `cf` CLI on `pylv-onyx` to inspect the remotely managed DNS and tunnel configuration:

```bash
cf dns records list --zone pylv.dev --name claw.pylv.dev --per-page 5
cf tunnels list --is-deleted false
cf tunnels config get d5120ed4-e5e0-4d21-9255-973d2b37c57c
cf zero-trust access applications list --domain '*.pylv.dev' --exact
```

Tunnel configuration updates replace the complete configuration. Preserve the existing Hermes ingress, origin options, and final catchall when changing the Claw route. Keep tunnel credentials outside the repository and the Nix store. An unauthenticated request to the public URL must reach Cloudflare Access; verify the UI and WebSocket connection after signing in as well.

## ChatGPT MCP relay

The [bundled MCP Relay plugin](https://docs.openclaw.ai/plugins/mcp-relay) connects outbound to OpenClaw's relay. It requires a release that includes `mcp-relay`; the published `2026.10.10-beta.1` package includes it, while `2026.10.5` stable does not. Application updates and relay configuration remain user-owned. Use a verified backup and an explicitly selected release when updating for this feature.

If `plugins.allow` is configured, append `mcp-relay` without removing existing entries before running `openclaw plugins enable mcp-relay`. Restart the Gateway and inspect the connection with `openclaw mcp-relay status --json`. Enabling the plugin does not authorize a ChatGPT account by itself.

Connect ChatGPT to `https://mcp.openclaw.ai/mcp`, then use the Gateway sign-in flow with `https://claw.pylv.dev` and approve the requested access in OpenClaw. Do not paste the Gateway password or token into ChatGPT. The relay connection uses TLS, but the relay service can read the relayed traffic. The public Control UI route and the outbound relay connection are separate.

## Agent-core integration

When `modules.openclaw.agentCore.enable` is true, Home Manager installs OpenClaw's generated instructions under `~/.local/share/openclaw/agent-core/` and materializes the `agent-core-context` extension under `~/.local/share/openclaw/extensions/`. The separate `modules.openclaw.agentSessionRecordPlugin.enable` option installs the `agent-session-record` extension there. Both options require the Home Manager integration's `modules.openclaw.enable`; `base/pylv/onyx.nix` enables all three. OpenClaw rejects Nix store hardlinks for externally loaded skills and plugin manifests, so activation copies extension trees instead of linking them into the store. The shared [Agent skills activation](../agent-skills/README.md) installs or updates skills as project copies with pinned `skills@1.7.2` on each switch, using `~/.local/share/openclaw/agent-core` as its working directory. Keeping managed resources outside mutable OpenClaw state prevents them from entering state archives. The `agent-core-context` extension uses `before_prompt_build` to return `prependSystemContext`. Workspace instructions remain independently owned and are loaded through OpenClaw's normal bootstrap path.

Before the first switch on an existing host, back up the external managed skill tree separately from the OpenClaw state archive, along with the CLI lock and ownership record. Verify ownership and explicitly move the old read-only skill tree to its backup location before switching so activation can install CLI copies at the same path. Activation does not delete or adopt conflicting trees automatically. Preserve `skills.load.extraDirs`, hook and recorder configuration, and the service environment drop-in. A successful switch needs no separate installation command. Host migration remains incomplete until installation and live discovery pass on pylv-onyx; see [Agent core recovery](../../agent-core/README.md#skill-설치와-복구).

The module does not edit mutable `openclaw.json`. Add the managed skill root to `skills.load.extraDirs`, enable the hook, and grant the conversation access required by `before_prompt_build`. This example assumes both integration options are enabled; omit the recorder path and allowlist entry when `agentSessionRecordPlugin.enable` is false:

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

The script obtains expected names from `agent-core skill-plan --target openclaw`, checks their installed files and unique discovery entries for every configured agent, and verifies the paths returned by `skills info`. Unrelated skills are allowed. Workspace overrides must resolve inside the reported workspace and are checked separately from managed installation files. It also checks context and recorder plugin activation, diagnostics, their `before_prompt_build` and `session_end` hooks, and the ordinary service environment drop-in. `AGENT_CORE_BIN` can select another agent-core executable. It reports a skipped multi-workspace check when all configured agents share one workspace. Exact live prompt contents require a trajectory export and are not collected by this smoke test. Run `deployed-skills.test.sh` as well to check ordinary files throughout declared skill trees and both extension trees.

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
modules/openclaw/tests/deployed-skills.test.sh
```

After updating `skills.load.extraDirs` and `plugins.load.paths`, validating the config, and restarting the Gateway, create and verify a fresh archive outside the state and workspace trees:

```bash
openclaw config validate
mkdir -p ~/backups/openclaw
openclaw backup create --output ~/backups/openclaw --verify
```

The command prints the created archive path. Run `openclaw backup verify <archive-path>` for an independent repeat verification, then check `openclaw status --json | jq '.backups.latest'` for a recorded `status` of `success`. A remaining failure at `~/.openclaw/codex-openclaw-home/auth.json` is separate legacy mutable state, not a Home Manager-owned integration resource; resolve that credential link before treating the archive as complete.

## Session recorder

The session recorder plugin subscribes to OpenClaw's `session_end` event and reads the transcript through OpenClaw 2.0's session identity API. It passes the returned events to `agent-session-record` without depending on an active transcript file path. The plugin hashes the session key locally and passes it as `session_key_hash`; it does not send the raw key to `agent-session-record`. If mutable OpenClaw configuration defines `plugins.allow`, include `agent-session-record` in that list.
