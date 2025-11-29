# Claude Module

This module installs and configures Claude Code, an AI coding assistant from Anthropic.

## What it does

- Installs `claude-code` from nixpkgs master
- Configures Claude Code settings (`~/.claude/settings.json`)
- Sets up MCP servers (`~/.claude/mcp.json`)
- Installs global instructions (`~/.claude/CLAUDE.md`)
- Installs custom agents (`~/.claude/agents/`)
- Creates `ccusage` alias for usage tracking

## Configuration Files

### settings.json

- **Model**: `opus` (default)
- **MCP**: Enables all project MCP servers
- **Permissions**: Pre-approved commands for common operations
  - File operations: `find`, `grep`, `cp`, `ls`, `mv`, `mkdir`, `rm`, `cat`, `sed`, `chmod`
  - Web fetch: `github.com`
  - MCP tools: `context7` library resolution and docs

### mcp.json

Configures MCP servers:

- **Context7**: Provides up-to-date library documentation via HTTP MCP

### CLAUDE.md

Global instructions for Claude Code behavior across all projects.

## Custom Agents

Located in `agents/` directory:

- **code-reviewer**: Code review agent
- **software-dev-engineer**: Software development guidance
- **test-code-writer**: Test code generation

## Usage

```bash
# Run Claude Code
claude

# Check usage statistics
ccusage
```
