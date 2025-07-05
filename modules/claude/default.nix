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
}
