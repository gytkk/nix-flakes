{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./ccusage.nix
  ];

  # Install Claude Code - AI coding assistant
  home.packages = [
    pkgs.claude-code
  ];
}
