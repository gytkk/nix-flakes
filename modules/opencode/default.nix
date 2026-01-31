{ pkgs, ... }:

{
  # Install OpenCode - open source AI coding agent
  # Use nixpkgs master for the latest version
  home.packages = [
    pkgs.master.opencode
  ];

  # Create ~/.config/opencode/opencode.json file
  home.file.".config/opencode/opencode.json".source = ./files/opencode.json;

  # Create ~/.config/opencode/AGENTS.md file
  home.file.".config/opencode/AGENTS.md".source = ./files/AGENTS.md;

  # Create ~/.config/opencode/agents/ directory
  home.file.".config/opencode/agents".source = ./files/agents;

  # Create ~/.config/opencode/skills/ directory
  home.file.".config/opencode/skills".source = ./files/skills;
}
