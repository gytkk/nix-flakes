# Claude Code Module

This module installs and configures Claude Code, Anthropic's AI coding assistant.

## What it does

- Installs `claude-code` from [sadjow/claude-code-nix](https://github.com/sadjow/claude-code-nix) flake
- Configures Claude Code settings (`~/.claude/settings.json`)
- Installs global development guidelines (`~/.claude/CLAUDE.md`)
- Installs plugin marketplaces, plugins, and MCP servers via activation scripts
- Installs plannotator CLI for visual plan review

## Configuration Files

### settings.json

- **Model**: Inherits the Claude Code default (no `model` pin)
- **Agent Teams**: Enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
- **MCP**: Enables all project MCP servers and Context7; Notion uses the `ntn` CLI
- **Permissions**: Pre-approved tools (Bash, Read, Edit, WebFetch, Context7)
- **Permission Mode**: `acceptEdits` for the working directory and Claude default repo-local worktrees
- **Memory** (experimental): `autoMemoryEnabled` + `autoDreamEnabled` — native background insight extraction and 24h consolidation
- **Language**: English

### CLAUDE.md

Global development guidelines deployed to `~/.claude/CLAUDE.md`. Includes:

- Verification & Inquiry Protocol
- Git conventions (conventional commits, atomic changes)
- Worktree workflow using Claude default repo-local worktrees
- Planning & Approval (plannotator integration)
- Code style rules (TDD, type safety, error handling)
- Python conventions (`uv run`)
- Prompt keywords (`webs` for aggressive web search)

## Plugins

### Marketplaces

- `anthropics/skills`, `anthropics/claude-code`, `anthropics/claude-plugins-official`
- `gytkk` (local marketplace — `modules/claude/marketplace`)
- `backnotprop/plannotator`
- `openai/codex-plugin-cc`

### Installed Plugins

- `document-skills`, `commit-commands`, `security-guidance`
- `ralph-loop`, `superpowers`
- LSP plugins: `gopls-lsp`, `rust-analyzer-lsp`, `typescript-lsp`, `metals-lsp`, `ty-lsp`, `terraform-ls`, `nixd-lsp`
- `plannotator` (visual plan annotation and review)
- `codex` (official OpenAI Codex plugin — provides `/codex:review`, `/codex:rescue`, etc.)
- `devils-advocate` (skeptical multi-pass review skill)

## MCP Servers

- **context7**: Library documentation lookup

## Notion

Use the `ntn` CLI for Notion pages, data sources, and API actions. The Notion MCP
server is intentionally removed during activation.

## Usage

```bash
# Run Claude Code
claude
```
