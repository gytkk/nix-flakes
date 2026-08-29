{
  lib,
  pkgs,
  localSkillsRoot,
}:

let
  sharedSkills = import ../agent-prompts/skills.nix { inherit lib pkgs; };
  localSkillDirectories = lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./skills);
  localSkillSources = lib.mapAttrs (name: _: "${localSkillsRoot}/${name}") localSkillDirectories;
  collisions = lib.intersectLists (builtins.attrNames localSkillSources) (
    builtins.attrNames sharedSkills.shared
  );
in
assert collisions == [ ];
sharedSkills.mkSkillFarm "codex-admin-skills" (localSkillSources // sharedSkills.shared)
