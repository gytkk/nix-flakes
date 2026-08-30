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

  mkSkillFarm =
    name: sources:
    pkgs.linkFarm name (
      lib.mapAttrsToList (skillName: path: {
        name = skillName;
        inherit path;
      }) sources
    );
in
{
  inherit mkSkillFarm official;
  shared = official;
}
