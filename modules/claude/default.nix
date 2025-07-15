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

  # Create ~/.claude/settings.json file
  home.file.".claude/settings.json".source = ./files/settings.json;

  # Create ~/.claude/CLAUDE.md file
  home.file.".claude/CLAUDE.md".source = ./files/CLAUDE.md;

  # Create update script and source it in shell
  home.file.".claude/update-config.sh" = {
    text = ''
      #!/bin/bash
      # Update ~/.claude.json (merge with files/claude.json)
      CLAUDE_JSON="$HOME/.claude.json"
      OVERRIDE_FILE="${./files/claude.json}"

      if [ -f "$CLAUDE_JSON" ]; then
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$CLAUDE_JSON" "$OVERRIDE_FILE" > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
      else
        cp "$OVERRIDE_FILE" "$CLAUDE_JSON"
        chmod 644 "$CLAUDE_JSON"
      fi
    '';
    executable = true;
  };

  # Update Claude configuration during home-manager activation
  home.activation.updateClaudeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Update Claude configuration
    if [[ -f ~/.claude/update-config.sh ]]; then
      source ~/.claude/update-config.sh
    fi
  '';

  home.shellAliases = {
    # Create ccusage alias for npx ccusage@latest
    ccusage = "npx ccusage@latest";
  };
}
