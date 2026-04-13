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

- **Model**: `opus` (default)
- **Agent Teams**: Enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
- **MCP**: Enables all project MCP servers, Context7, Notion
- **Permissions**: Pre-approved tools (Bash, Read, Edit, WebFetch, Context7)
- **Language**: Korean

### CLAUDE.md

Global development guidelines deployed to `~/.claude/CLAUDE.md`. Includes:

- Verification & Inquiry Protocol
- Git conventions (conventional commits, atomic changes)
- Worktree workflow
- Planning & Approval (plannotator integration)
- Code style rules (TDD, type safety, error handling)
- Python conventions (`uv run`)
- Prompt keywords (`webs` for aggressive web search)

## Plugins

### Marketplaces

- `anthropics/skills`, `anthropics/claude-code`, `anthropics/claude-plugins-official`
- `gytkk/claude-marketplace`
- `backnotprop/plannotator`
- `openai/codex-plugin-cc`
- `thedotmack/claude-mem`

### Installed Plugins

- `document-skills`, `commit-commands`, `security-guidance`
- `ralph-loop`
- LSP plugins: `gopls-lsp`, `rust-analyzer-lsp`, `typescript-lsp`, `metals-lsp`, `ty-lsp`, `terraform-ls`, `nixd-lsp`
- `plannotator` (visual plan annotation and review)
- `codex` (official OpenAI Codex plugin — provides `/codex:review`, `/codex:rescue`, etc.)
- `claude-mem` (persistent memory compression across Claude Code sessions)

## MCP Servers

- **context7**: Library documentation lookup
- **notion**: Notion integration

## Usage

```bash
# Run Claude Code
claude
```
