# Pi coding agent module

This module manages the global Pi coding-agent setup used by this repository.
It installs Pi and the NixOS MCP server, then exposes tracked configuration
under `~/.pi/agent/` through generated files and Home Manager out-of-store
symlinks.

See [`docs/pi-performance-audit.md`](../../docs/pi-performance-audit.md) for the
current performance findings, measurements, and prioritized action items.

## Managed resources

| Repository path | Runtime path | Purpose |
| --- | --- | --- |
| `files/settings.json` | `~/.pi/agent/settings.json` | Pi defaults and pinned packages |
| `files/web-search.json` | `~/.pi/web-search.json` | Web Access defaults |
| `files/mcp.json` | `~/.pi/agent/mcp.json` | MCP adapter and server configuration |
| `files/models.json` | `~/.pi/agent/models.json` | Custom Databricks model provider |
| `agent-rules/` and `files/AGENTS.md` | `~/.pi/agent/AGENTS.md` | Generated shared and Pi-specific instructions |
| `agent-rules/rules/OPERATING.md` | `~/.pi/agent/APPEND_SYSTEM.md` | Operating invariants added to Pi's system prompt |
| `files/extensions/` | `~/.pi/agent/extensions/` | Local Pi extensions |
| `files/themes/claude-like.json` | `~/.pi/agent/themes/claude-like.json` | Global dark theme |
| `skills/` | `~/.pi/agent/skills/` | Repository-managed Pi skills |

The module also installs:

- `pkgs.pi`
- `pkgs.mcp-nixos`

Mutable configuration uses out-of-store symlinks, so commands such as
`/settings` can modify tracked source files directly. Generated instruction
files change only after applying the Home Manager configuration. Review
`git diff` after changing Pi configuration interactively.

## Main settings

`files/settings.json` currently selects:

- `openai-codex/gpt-5.6-sol` with `high` thinking
- the `claude-like` theme
- one-cell editor and output padding
- the hardware terminal cursor for IME positioning

`files/web-search.json` sets the default Web Access workflow to `none`, so
ordinary searches return directly without opening the curator. Requests that
need human source selection can still set `workflow: "summary-review"` or use
`/curator` explicitly.

## Databricks Kimi K3

`files/models.json` configures `system.ai.kimi-k3` through the
`databricks-logapne1` provider. Launch it with:

```bash
pi --provider databricks-logapne1 --model system.ai.kimi-k3
```

The provider retrieves an OAuth access token at request time through
`databricks auth token logapne1 -o json`; the token is not stored in the
repository or Pi configuration. The Databricks CLI must be installed and have
a `logapne1` profile configured. Other hosts cannot invoke this provider
without that CLI and profile.

The package list is intentionally version-pinned:

| Package | Version | Purpose |
| --- | --- | --- |
| `@juicesharp/rpiv-ask-user-question` | `2.4.0` | Structured user questions |
| `pi-web-access` | `0.18.0` | Web search, source checks, and content fetching |
| `pi-mcp-adapter` | `2.20.1` | Token-efficient MCP discovery and calls |
| `pi-subagents` | `0.41.0` | Foreground-first delegated Pi sessions |

Versioned npm packages are skipped by `pi update --extensions`. Update pins
through a reviewed repository change, and review package source and release
notes because Pi packages execute with the permissions of the Pi process.

`pi-subagents` loads only its extension; its bundled skills and prompt
templates are filtered out so they cannot opt into background workflows or
wide fanout. The initial rollout uses packaged agents with explicit
Luna/Terra/Sol routing. Delegation defaults to foreground, stores artifacts
under the parent Pi session, allows eight child launches per parent session,
and blocks nested delegation at child depth. Automatic missions, schedules,
and the generic `delegate` agent are disabled.

The packaged `planner`, `worker`, and `oracle` fork defaults are overridden to
fresh context. Use an explicit `context: "fork"` only when the child genuinely
needs the parent transcript; otherwise pass a compact task contract. The
`researcher` also skips inherited project instructions because its role prompt
and research task provide its operating context. Other agents retain project
instruction inheritance. When a child persists a substantial artifact, prefer
`outputMode: "file-only"` so the full result is not injected back into the
parent context.

Only `worker` retains normal implementation tools. `scout`, `researcher`,
`context-builder`, and `reviewer` have no `edit` or `write` tool. Their `bash`
access is for inspection and verification and is not a security boundary; Pi
packages and child processes still run with the current user's permissions.
For the initial rollout, use one direct foreground child at a time and do not
request `workflowScript`, background runs, or worktrees. The configured global
concurrency limit protects legacy multi-child paths but does not cap
`workflowScript` `runs.all()` fanout in pi-subagents 0.41.0.

## Global prompts and skills

`modules/agent-rules/rules/OPERATING.md` is exposed as `APPEND_SYSTEM.md`, so it
augments Pi's maintained system prompt instead of replacing it. It is the single
source of repository-independent operating invariants that must apply to every
task.

`files/AGENTS.md` contains Pi-specific operational policy. Home Manager prepends
shared methodology from `modules/agent-rules/AGENTS.md` and writing guidance
from `modules/agent-rules/rules/WRITING.md` when it generates the runtime
`~/.pi/agent/AGENTS.md`. It omits `OPERATING.md` from that generated file because
Pi already loads those rules through `APPEND_SYSTEM.md`. Project-specific rules
belong in the project's own `AGENTS.md`; focused workflows belong in
`modules/pi/skills/`.

The currently managed skills are:

- `devils-advocate`
- `parallel-research-merge`
- `pi-agent`

## Local extensions

### Codex fast mode

`files/extensions/codex-fast-mode.ts` provides:

- `/fast [on|off|status]`
- `service_tier: "priority"` for `openai-codex` requests while enabled
- a one-line footer with working directory, Git branch, model, thinking level,
  fast-mode state, context usage, and cumulative input/output tokens

Fast mode starts enabled in each new session. Toggle changes are stored in the
session so resumed branches recover their previous state. The extension is the
sole owner of the custom footer and priority-mode request field.

Subagent child processes are detected through `PI_SUBAGENT_CHILD=1` and do
not receive the priority service tier. `PI_SUBAGENT_PARENT_SESSION` is also set
in the parent UI session for permission forwarding, so it must not be used as
the child-process signal. Parent Pi sessions continue to use fast mode normally.

### Codex usage

`files/extensions/codex-usage.ts` provides `/codex-usage`, which fetches the
current account-level Codex rate-limit windows with Pi's existing
`openai-codex` OAuth credential. It reports remaining capacity rather than
consumed capacity and formats reset timestamps in the local timezone.

For parent sessions using an `openai-codex` model, the extension refreshes after
the agent settles and publishes a compact weekly remaining percentage and
reset time (`#########- 97% ⏳ 08/18 09:29`) to the custom footer immediately
left of the model. The footer keeps a single rendered line and hides the usage
segment when the terminal is too narrow to preserve the existing left-side
status content.
The status is also hidden for other providers and for subagent child processes.
Automatic refresh failures are silent and do not interrupt Pi; an explicit
`/codex-usage` reports errors.
OAuth tokens are used only for the request and are never persisted or logged by
the extension.

The usage request targets ChatGPT's internal Codex usage endpoint. Its schema is
not a public API, so review this extension if OpenAI changes Codex usage
reporting or authentication.

### Hardware cursor rendering

`files/extensions/hardware-cursor-only.ts` removes Pi's reverse-video software
cursor while preserving the terminal cursor used for IME positioning. It is
paired with `showHardwareCursor: true` in `settings.json`.

This extension depends on Pi 0.83's editor rendering behavior. Review it when
updating Pi if cursor rendering or IME positioning changes.

## MCP integration

`files/mcp.json` configures `pi-mcp-adapter` with:

- `nixos`, provided by the installed `mcp-nixos` executable
- `cloudflare`, using an agenix-decrypted bearer token
- `context7`, using its remote MCP endpoint

The servers are declared explicitly because this repository does not rely on
the adapter importing another agent's MCP configuration. The adapter status
icon is disabled so the footer uses plain `MCP: ...` status text, rendered in
bright green by the custom footer.

Create an account-owned Cloudflare API token scoped to the intended account
with `Account Resources Read`, `Access: Apps and Policies Read`, and
`Access: Apps and Policies Write`. Set an expiry appropriate for the intended
rotation interval, then store it without exposing the plaintext to the
repository or shell history:

```bash
agx -e cloudflare-access-api-token.age
```

The Cloudflare MCP entry resolves
`!agx -d cloudflare-access-api-token.age` only when it connects. The adapter
suppresses the command's standard error and uses its trimmed standard output as
the bearer token; the plaintext is not stored in `mcp.json`.

### Cloudflare OAuth limitation

`pi-mcp-adapter` 2.20.1 cannot complete Cloudflare OAuth because it drops the
RFC 9207 `iss` callback value before handing the response to the MCP SDK. The
SDK then reports an issuer mismatch even though Cloudflare returned the issuer.

The upstream fix was merged in
[`pi-mcp-adapter#294`](https://github.com/nicobailon/pi-mcp-adapter/pull/294),
but is not included in the pinned release. This module therefore uses the
agenix-backed bearer token above. Do not disable issuer validation as a
workaround. After upgrading, OAuth can be reconsidered separately.

## Theme

`files/themes/claude-like.json` is a dark theme with an Anthropic-inspired
orange accent and warm neutral colors. It covers messages, tool blocks,
Markdown, diffs, syntax highlighting, and editor borders.

Ordinary text uses the terminal's default foreground. The custom footer uses
its own ANSI palette independently of the theme.

## Verification

After changing this module:

1. Validate edited JSON files with `jq -e . <file>`.
2. Run `nixfmt modules/pi/default.nix` when the Nix module changes.
3. Run `nix flake check --no-build` when module wiring changes.
4. Apply the Home Manager configuration manually:

   ```bash
   home-manager switch --flake .#<environment>
   ```

5. Confirm the runtime configuration:

   ```bash
   pi --version
   pi list
   ```

6. In Pi, verify `/fast status`, MCP discovery, structured questions, and the
   web-access tools relevant to the change.

For the subagent rollout, also run `/subagents-doctor` and
`/subagents-models`, then verify one foreground `scout`, one `researcher`, and
a read-only `reviewer` before trying `worker` against a disposable fixture.
Confirm that no `.pi-subagents/` directory or additional Git worktree appears
in the repository.

Do not commit credentials, OAuth tokens, API keys, `auth.json`, session files,
or MCP credential caches. Pi has no built-in sandbox; packages, extensions,
skills, and tool commands run with the current user's permissions.
