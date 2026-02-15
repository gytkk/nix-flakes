{ pkgs, ... }:

{
  # Install OpenCode via gytkk/flake-stores (pre-built binary)
  home.packages = [
    pkgs.opencode
  ];

  # Create ~/.config/opencode/opencode.json file
  home.file.".config/opencode/opencode.json".source = ./files/opencode.json;

  # Create ~/.config/opencode/oh-my-opencode.json file (oh-my-opencode plugin config)
  home.file.".config/opencode/oh-my-opencode.json".source = ./files/oh-my-opencode.json;

  # Deploy native notification plugin (uses OSC 777 for Ghostty desktop notifications)
  home.file.".config/opencode/plugins/native-notify.ts".source = ./files/plugins/native-notify.ts;

  # Create ~/.config/opencode/AGENTS.md file
  home.file.".config/opencode/AGENTS.md".source = ./files/AGENTS.md;

  # Create ~/.config/opencode/agents/ directory
  home.file.".config/opencode/agents".source = ./files/agents;
}
