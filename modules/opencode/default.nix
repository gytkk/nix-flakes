{ pkgs, ... }:

{
  # Install OpenCode - open source AI coding agent
  # Use nixpkgs master for the latest version
  home.packages = [
    pkgs.master.opencode
  ];

  # Create ~/.config/opencode/opencode.json file
  home.file.".config/opencode/opencode.json".source = ./files/opencode.json;

  # Create ~/.config/opencode/oh-my-opencode.json file (oh-my-opencode plugin config)
  home.file.".config/opencode/oh-my-opencode.json".source = ./files/oh-my-opencode.json;

  # Create ~/.config/opencode/opencode-notifier.json file (notifier plugin config)
  # Uses OSC 9 escape sequence for Ghostty native desktop notifications
  # instead of osascript which shows as "Script Editor" in macOS
  home.file.".config/opencode/opencode-notifier.json".source = ./files/opencode-notifier.json;

  # Create ~/.config/opencode/AGENTS.md file
  home.file.".config/opencode/AGENTS.md".source = ./files/AGENTS.md;

  # Create ~/.config/opencode/agents/ directory
  home.file.".config/opencode/agents".source = ./files/agents;
}
