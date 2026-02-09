{ pkgs, ... }:

{
  # Install Claude Code - AI coding assistant
  home.packages = [
    pkgs.master.claude-code
  ];

  # Create ~/.claude/settings.json file
  home.file.".claude/settings.json".source = ./files/settings.json;

  # Create ~/.claude/mcp.json file for MCP server configuration
  home.file.".claude/mcp.json".source = ./files/mcp.json;

  # Create ~/.claude/CLAUDE.md file
  home.file.".claude/CLAUDE.md".source = ./files/CLAUDE.md;

  # Copy all agent files to ~/.claude/agents
  home.file.".claude/agents".source = ./agents;
}
