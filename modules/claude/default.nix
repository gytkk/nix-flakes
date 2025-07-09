{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Install Claude Code - AI coding assistant
  home.packages = [
    pkgs.claude-code
  ];

  # Create ccusage alias for npx ccusage@latest
  programs.zsh.shellAliases.ccusage = "npx ccusage@latest";

  # Create ~/.claude/settings.json file
  home.file.".claude/settings.json".source = ./files/settings.json;

  # Create ~/.claude/CLAUDE.md file
  home.file.".claude/CLAUDE.md".source = ./files/CLAUDE.md;
}
