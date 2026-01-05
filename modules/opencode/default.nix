{ pkgs, ... }:

{
  # Install OpenCode - open source AI coding agent
  home.packages = [
    pkgs.opencode
  ];

  # Create ~/.config/opencode/opencode.json file
  home.file.".config/opencode/opencode.json".source = ./files/opencode.json;

  # Create ~/.config/opencode/AGENTS.md file
  home.file.".config/opencode/AGENTS.md".source = ./files/AGENTS.md;
}
