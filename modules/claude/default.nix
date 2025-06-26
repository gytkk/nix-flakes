{ config, lib, pkgs, ... }:

{
  # Install Claude Code - AI coding assistant
  home.packages = [
    pkgs.claude-code
  ];

  # Set environment variables for Claude Code
  home.sessionVariables = {
    # Enable MCP support for Claude Code
    CLAUDE_CODE_MCP_ENABLED = "true";
  };
}
