{
  config,
  lib,
  pkgs,
  flakeDirectory,
  ...
}:

let
  cfg = config.modules.pi;
  agentPrompts = import ../agent-prompts/lib.nix { inherit lib pkgs; };
  sharedSkills = import ../agent-prompts/skills.nix { inherit lib pkgs; };
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/pi/${path}";
  localSkillDirectories = lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./skills);
  localSkillSources = lib.mapAttrs (
    name: _: "${flakeDirectory}/modules/pi/skills/${name}"
  ) localSkillDirectories;
  skillCollisions = lib.intersectLists (builtins.attrNames localSkillSources) (
    builtins.attrNames sharedSkills.shared
  );
  managedSkills = sharedSkills.mkSkillFarm "pi-agent-skills" (
    localSkillSources // sharedSkills.shared
  );
in
{
  options.modules.pi.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Pi coding agent CLI";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = skillCollisions == [ ];
        message = "Pi local skills conflict with shared skills: ${lib.concatStringsSep ", " skillCollisions}";
      }
    ];

    home.packages = [
      pkgs.pi
      pkgs.mcp-nixos
    ];

    home.file = {
      ".pi/agent/AGENTS.md".source = agentPrompts.renderWithoutOperating "pi-AGENTS.md" [
        ./files/AGENTS.md
      ];
      ".pi/agent/APPEND_SYSTEM.md".source = agentPrompts.operatingRules;
      ".pi/agent/keybindings.json".source = mkSymlink "files/keybindings.json";
      ".pi/agent/lsp.json".source = mkSymlink "files/lsp.json";
      ".pi/agent/mcp.json".source = mkSymlink "files/mcp.json";
      ".pi/agent/models.json".source = mkSymlink "files/models.json";
      ".pi/agent/settings.json".source = mkSymlink "files/settings.json";
      ".pi/web-search.json".source = mkSymlink "files/web-search.json";
      ".pi/agent/themes/claude-like.json".source = mkSymlink "files/themes/claude-like.json";
      ".pi/agent/extensions/codex-fast-mode.ts".source = mkSymlink "files/extensions/codex-fast-mode.ts";
      ".pi/agent/extensions/codex-usage.ts".source = mkSymlink "files/extensions/codex-usage.ts";
      ".pi/agent/extensions/hardware-cursor-only.ts".source =
        mkSymlink "files/extensions/hardware-cursor-only.ts";
      ".pi/agent/extensions/tool-profiles".source = mkSymlink "files/extensions/tool-profiles";
      ".pi/agent/extensions/subagent/config.json".source =
        mkSymlink "files/extensions/subagent/config.json";
      ".pi/agent/skills".source = managedSkills;
    };
  };
}
