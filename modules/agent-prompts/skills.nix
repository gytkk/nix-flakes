{
  lib,
  pkgs,
}:

let
  skillsRoot = builtins.path {
    path = ./skills;
    name = "agent-prompt-skills";
  };
  skillDirectories = lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./skills);
  official = lib.mapAttrs (name: _: skillsRoot + "/${name}") skillDirectories;

  # Keep explicit Claude-only additions separate from the portable official set.
  claudeOnly = { };
  claudeOnlyCollisions = lib.intersectLists (builtins.attrNames official) (
    builtins.attrNames claudeOnly
  );

  mkSkillFarm =
    name: sources:
    pkgs.linkFarm name (
      lib.mapAttrsToList (skillName: path: {
        name = skillName;
        inherit path;
      }) sources
    );
in
assert claudeOnlyCollisions == [ ];
{
  inherit claudeOnly mkSkillFarm official;
  shared = official;
  claude = official // claudeOnly;
}
