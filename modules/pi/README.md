# Pi coding agent module

This module manages the global Pi coding-agent setup used by this repository.
It installs Pi and the NixOS MCP server, then exposes tracked configuration
under `~/.pi/agent/` with Home Manager out-of-store symlinks.

## Managed resources

| Repository path | Runtime path | Purpose |
| --- | --- | --- |
| `files/settings.json` | `~/.pi/agent/settings.json` | Pi defaults and pinned packages |
| `files/mcp.json` | `~/.pi/agent/mcp.json` | MCP adapter and server configuration |
| `files/AGENTS.md` | `~/.pi/agent/AGENTS.md` | Global agent instructions |
| `files/SYSTEM_PROMPT.md` | `~/.pi/agent/APPEND_SYSTEM.md` | Additions to Pi's maintained system prompt |
| `files/extensions/` | `~/.pi/agent/extensions/` | Local Pi extensions |
| `files/themes/claude-like.json` | `~/.pi/agent/themes/claude-like.json` | Global dark theme |
| `skills/` | `~/.pi/agent/skills/` | Repository-managed Pi skills |

The module also installs:

- `pkgs.pi`
- `pkgs.mcp-nixos`

Because these files use out-of-store symlinks, commands such as `/settings`
can modify the tracked source files directly. Review `git diff` after changing
Pi configuration interactively.

## Main settings

`files/settings.json` currently selects:

- `openai-codex/gpt-5.6-sol` with `high` thinking
- the `claude-like` theme
- one-cell editor and output padding
- the hardware terminal cursor for IME positioning

The package list is intentionally version-pinned:

| Package | Version | Purpose |
| --- | --- | --- |
| `@juicesharp/rpiv-ask-user-question` | `2.4.0` | Structured user questions |
| `pi-web-access` | `0.18.0` | Web search, source checks, and content fetching |
| `pi-mcp-adapter` | `2.20.1` | Token-efficient MCP discovery and calls |

Versioned npm packages are skipped by `pi update --extensions`. Update pins
through a reviewed repository change, and review package source and release
notes because Pi packages execute with the permissions of the Pi process.

## Global prompts and skills

`files/SYSTEM_PROMPT.md` is exposed as `APPEND_SYSTEM.md`, so it augments Pi's
maintained system prompt instead of replacing it. Keep it concise and
repository-independent.

`files/AGENTS.md` contains the global operating rules. Project-specific rules
belong in the project's own `AGENTS.md`; focused reusable workflows belong in
`modules/pi/skills/`.

The currently managed skills are:

- `devils-advocate`
- `karpathy-guidelines`
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

### Hardware cursor rendering

`files/extensions/hardware-cursor-only.ts` removes Pi's reverse-video software
cursor while preserving the terminal cursor used for IME positioning. It is
paired with `showHardwareCursor: true` in `settings.json`.

This extension depends on Pi 0.83's editor rendering behavior. Review it when
updating Pi if cursor rendering or IME positioning changes.

## MCP integration

`files/mcp.json` configures `pi-mcp-adapter` with:

- `nixos`, provided by the installed `mcp-nixos` executable
- `cloudflare`, using OAuth
- `context7`, using its remote MCP endpoint

The servers are declared explicitly because this repository does not rely on
the adapter importing another agent's MCP configuration. The adapter status
icon is disabled so the footer uses plain `MCP: ...` status text.

Authenticate Cloudflare with:

```text
/mcp-auth cloudflare
```

### Cloudflare OAuth limitation

`pi-mcp-adapter` 2.20.1 cannot complete Cloudflare OAuth because it drops the
RFC 9207 `iss` callback value before handing the response to the MCP SDK. The
SDK then reports an issuer mismatch even though Cloudflare returned the issuer.

The upstream fix was merged in
[`pi-mcp-adapter#294`](https://github.com/nicobailon/pi-mcp-adapter/pull/294),
but is not included in the pinned release. Wait for a release containing that
fix or use bearer-token authentication. Do not disable issuer validation as a
workaround. After upgrading, restart Pi and authenticate again.

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

Do not commit credentials, OAuth tokens, API keys, `auth.json`, session files,
or MCP credential caches. Pi has no built-in sandbox; packages, extensions,
skills, and tool commands run with the current user's permissions.
