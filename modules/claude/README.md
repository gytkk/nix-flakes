# Claude Code Module

This module installs and configures Claude Code, Anthropic's AI coding assistant.

## What it does

- Installs `claude-code` from the repository's [app package catalog](../../packages/apps/README.md), exposed through the configuration overlay
- Configures Claude Code settings (`~/.claude/settings.json`)
- Installs global development guidelines (`~/.claude/CLAUDE.md`)
- Installs plugin marketplaces, plugins, and MCP servers via activation scripts
- Installs plannotator CLI for visual plan review

## Configuration Files

### settings.json

- **Model**: Inherits the Claude Code default (no `model` pin)
- **Agent Teams**: Enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
- **MCP**: Enables all project MCP servers and Context7; Notion uses the `ntn` CLI
- **Permissions**: Pre-approved tools (Bash, Read, Edit, Write, WebFetch, WebSearch, Context7)
- **Permission Mode**: `acceptEdits` for the working directory and Claude default repo-local worktrees
- **Memory** (experimental): `autoMemoryEnabled` + `autoDreamEnabled` — native background insight extraction and 24h consolidation
- **Status line**: Working directory, Git branch, context/tokens/line changes, plus the Claude.ai weekly limit, selected model, and effort right-aligned
- **Language**: English

Inside Herdr, the status line also reports the selected model for the [Agents sidebar](../herdr/README.md#subagents). The model updates whenever Claude invokes the status line and expires after 45 seconds without an update, so it may disappear while Claude is idle. Missing model data clears the value. Reporting failures leave the terminal status line intact.

### CLAUDE.md

Global development guidelines are rendered from shared rules under `agent-core/rules/` and `agent-core/adapters/claude.md`, then deployed to `~/.claude/CLAUDE.md`.

## Herdr subagent sidebar

Inside Herdr, Claude's Agents entry displays native subagents with a status icon, name, and actual model, followed by a dimmed excerpt of the latest assistant message. Before a message is available, the activity can show the tool name. Thinking blocks, tool arguments, and tool results are not displayed. Children share the parent's pane; this integration does not create terminal panes.

[settings.json](files/settings.json) connects `SessionStart`, `SubagentStart`, `SubagentStop`, `PostToolUse` for `Agent`, and `SessionEnd` to `~/.local/bin/claude-herdr-subagents`. The [helper](files/herdr-subagents/index.ts) runs one watcher per Herdr pane and reads the current session's parent and child JSONL records. Background children continue to be watched after the parent finishes responding. Agent results supply task descriptions; until a result is available, the name is the agent type and a short ID. Resuming the same child updates its existing row.

Running uses a green `●`, confirmed completion a blue `✓`, interruption a yellow `■`, and failure a red `×`. `SubagentStop` alone shows `○` while the watcher waits for a parent result or Claude's task notification, because another stop hook can request more work. These states describe a run, not permanent termination of the agent. Completed, interrupted, and failed rows remain visible for five seconds. Missing or unreadable transcripts show `○` and retain the last message. If the watcher stops reporting, metadata expires within 15 seconds. The parent model remains independently reported by the status line.

The parser targets the pinned Claude Code 2.1.284 transcript format. Stop-only events from internal agents do not create rows. Independently launched Claude processes are not linked as children. Display limits are documented in [Herdr's subagent settings](../herdr/README.md#subagents).

Apply Home Manager for the current environment, run `herdr server reload-config`, and start a new Claude session inside Herdr. Verification uses isolated fixture transcripts and fake Herdr commands:

```bash
bun test modules/claude/tests
```

## Skills and plugins

The shared `typesafe-ai` skill provides TypeSafe's official Jev workflow guidance. Invoke it with `/typesafe-ai` and run API clients through `with-jev` to use the agenix key. See the [Jev README](../jev/README.md) for source provenance, authentication, and activation.

Home Manager installs Claude's immutable selection of shared skills from `agent-core/skills/` into `~/.claude/skills/`. The local `devils-advocate` marketplace plugin remains separately owned because it provides a Claude command, agent, and plugin metadata that the shared renderer does not model.

### Marketplaces

- `anthropics/skills`, `anthropics/claude-code`, `anthropics/claude-plugins-official`
- `gytkk` (local marketplace — `modules/claude/marketplace`)
- `backnotprop/plannotator`
- `openai/codex-plugin-cc`

### Installed Plugins

- `document-skills`, `commit-commands`, `security-guidance`
- `devils-advocate` (runtime-specific multi-pass review command and agent)
- `ralph-loop`, `superpowers`
- `slack` (Slack's hosted MCP server plus Slack developer skills)
- LSP plugins: `gopls-lsp`, `rust-analyzer-lsp`, `typescript-lsp`, `metals-lsp`, `ty-lsp`, `terraform-ls`, `nixd-lsp`
- `plannotator` (visual plan annotation and review)
- `codex` (official OpenAI Codex plugin — provides `/codex:review`, `/codex:rescue`, etc.)

## MCP Servers

- **context7**: Library documentation lookup
- **slack**: Provided by the `slack` plugin, not by `claude mcp add`. The plugin
  ships a pre-registered OAuth client id for `https://mcp.slack.com/mcp`;
  registering that URL directly would fail because Claude Code only performs
  Dynamic Client Registration, which Slack does not support. Authenticate with
  `/mcp` inside Claude Code. A Slack workspace admin must approve MCP
  integration for the workspace before authentication succeeds.

## Notion

Use the `ntn` CLI for Notion pages, data sources, and API actions. The Notion MCP
server is intentionally removed during activation.

Cloudflare operations use the `cf` CLI installed by the common Home Manager profile. Activation removes the legacy user-scope `cloudflare` MCP registration. See [Cloudflare CLI setup](../../README.md#cloudflare-cli) for authentication and command discovery.

## Usage

```bash
# Run Claude Code
claude
```
