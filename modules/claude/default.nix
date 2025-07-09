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
  home.file.".claude/settings.json".text = ''
    {
      "permissions": {
        "allow": [
          "Bash(find:*)",
          "Bash(mkdir:*)"
        ]
      }
    }
  '';

  # Create ~/.claude/CLAUDE.md file
  home.file.".claude/CLAUDE.md".text = ''
    # CLAUDE.md

    ## Critical Rules
    - First, deeply understand and think about what you want to achieve with your code.
    - Always follow existing code patterns and module structure.
    - Be concise. Commit small, frequent changes for readable diffs.
  '';
}
