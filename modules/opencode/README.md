# OpenCode Module

This module installs and configures OpenCode, an open source AI coding agent.

## What it does

- Installs `opencode` from nixpkgs
- Configures OpenCode settings (`~/.config/opencode/opencode.json`)
- Sets up MCP servers (`context7` for library documentation)
- Installs global instructions (`~/.config/opencode/AGENTS.md`)

## Configuration Files

### opencode.json

- **Model**: `anthropic/claude-opus-4-5` (default)
- **Theme**: `opencode`
- **Autoupdate**: enabled
- **MCP**: Context7 for up-to-date library documentation

### AGENTS.md

Global instructions for OpenCode behavior across all projects.

## Usage

```bash
# Run OpenCode
opencode

# Initialize project (creates AGENTS.md)
opencode
/init

# Switch between agents (Tab key)
```

## Built-in Agents

OpenCode includes two built-in primary agents:

- **build**: Default agent with full access for development work
- **plan**: Read-only agent for analysis and code exploration
