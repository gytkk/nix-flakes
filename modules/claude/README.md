# Claude Module

This module installs and configures Claude Code, an AI coding assistant from Anthropic,
with a Sisyphus-style agent orchestration system.

## What it does

- Installs `claude-code` from nixpkgs master
- Configures Claude Code settings (`~/.claude/settings.json`)
- Installs global orchestration instructions (`~/.claude/CLAUDE.md`)
- Deploys 6 custom subagents to `~/.claude/agents/`
- Installs plugin marketplaces, plugins, and MCP servers via activation scripts

## Configuration Files

### settings.json

- **Model**: `opus` (default)
- **Agent Teams**: Enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
- **MCP**: Enables all project MCP servers
- **Permissions**: Pre-approved commands for common operations
  - File operations: `find`, `grep`, `cp`, `ls`, `mv`, `mkdir`, `rm`, `cat`, `sed`, `chmod`
  - Web fetch: `github.com`
  - MCP tools: `context7` library resolution and docs

### CLAUDE.md

Global orchestration instructions that turn Claude into a strategic orchestrator (Sisyphus
pattern). Includes intent classification, delegation rules, verification protocol, failure
recovery, codebase assessment, and communication style guidelines.

## Custom Subagents (Sisyphus Orchestration)

Located in `agents/` directory, deployed to `~/.claude/agents/`:

| Agent | Model | Mode | Purpose |
|-------|-------|------|---------|
| **oracle** | opus | Read-only, memory | Strategic advisor for architecture, debugging, system design |
| **explorer** | haiku | Read-only | Fast codebase search, call chain tracing, context gathering |
| **librarian** | sonnet | Read-only | External docs, library APIs, OSS examples via Context7 + web |
| **planner** | opus | Read-only | Pre-implementation analysis, requirements, risk assessment |
| **reviewer** | opus | Read-only, memory | Code quality, security audit, pattern compliance |
| **implementer** | opus | Read-write | Autonomous code changes, feature building, bug fixes |

### Marketplace Agents (coexist with subagents)

Installed via `gytkk/claude-marketplace` plugin:

- **code-reviewer**: Code review for quality, bugs, and security
- **software-dev-engineer**: System design and architecture guidance
- **test-code-writer**: Test suite generation from specs or code

## Usage

```bash
# Run Claude Code
claude

# Check usage statistics
ccusage
```

## Architecture

The orchestration follows the Sisyphus pattern:

1. **Main agent** (reading CLAUDE.md) classifies intent and delegates
2. **Read-only subagents** (oracle, explorer, librarian, planner, reviewer) gather information
3. **Implementer subagent** executes code changes
4. **Main agent** verifies results and reports to user

Subagents cannot spawn other subagents — only the main agent orchestrates.
