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
}
