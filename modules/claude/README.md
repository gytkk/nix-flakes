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

## Usage

```bash
# Run Claude Code
claude
```
