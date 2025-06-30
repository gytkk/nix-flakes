# Claude Module

This module installs and configures Claude Code, an AI coding assistant from Anthropic.

## What it does

- Installs the `claude-code` package
- Enables MCP (Model Context Protocol) support for enhanced functionality
- Configures environment variables for optimal Claude Code experience

## Features

- **AI Coding Assistant**: Provides intelligent code completion, generation, and debugging assistance
- **MCP Support**: Enables Model Context Protocol for enhanced AI capabilities
- **Cross-platform**: Works on both macOS and Linux environments

## Requirements

- Nix package manager
- Home Manager
- Access to the `claude-code` package from nixpkgs

## Configuration

The module automatically sets:
- `CLAUDE_CODE_MCP_ENABLED=true` - Enables MCP support for enhanced functionality

## Usage

After installation, you can use Claude Code by running:
```bash
claude-code
```

The MCP support provides additional context and capabilities for better AI assistance.