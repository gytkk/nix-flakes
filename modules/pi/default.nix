{
  config,
  lib,
  pkgs,
  flakeDirectory,
  ...
}:

let
  cfg = config.modules.pi;
  agentRules = import ../agent-rules/lib.nix { inherit lib pkgs; };
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/pi/${path}";
in
{
  options.modules.pi.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Pi coding agent CLI";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.pi
      pkgs.mcp-nixos
    ];

    home.file.".pi/agent/AGENTS.md".source = agentRules.renderWithoutOperating "pi-AGENTS.md" [
      ./files/AGENTS.md
    ];
    home.file.".pi/agent/APPEND_SYSTEM.md".source = agentRules.operatingRules;
    home.file.".pi/agent/keybindings.json".source = mkSymlink "files/keybindings.json";
    home.file.".pi/agent/mcp.json".source = mkSymlink "files/mcp.json";
    home.file.".pi/agent/models.json".source = mkSymlink "files/models.json";
    home.file.".pi/agent/settings.json".source = mkSymlink "files/settings.json";
    home.file.".pi/web-search.json".source = mkSymlink "files/web-search.json";
    home.file.".pi/agent/themes/claude-like.json".source = mkSymlink "files/themes/claude-like.json";
    home.file.".pi/agent/extensions/codex-fast-mode.ts".source =
      mkSymlink "files/extensions/codex-fast-mode.ts";
    home.file.".pi/agent/extensions/codex-usage.ts".source =
      mkSymlink "files/extensions/codex-usage.ts";
    home.file.".pi/agent/extensions/hardware-cursor-only.ts".source =
      mkSymlink "files/extensions/hardware-cursor-only.ts";
    home.file.".pi/agent/extensions/subagent/config.json".source =
      mkSymlink "files/extensions/subagent/config.json";
    home.file.".pi/agent/skills".source = mkSymlink "skills";
  };
}
