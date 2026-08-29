{
  lib,
  pkgs,
  ...
}:

let
  managedSkills = import ./skills.nix {
    inherit lib pkgs;
    localSkillsRoot = ./skills;
  };
in
{
  environment.etc."codex/managed_config.toml".source = ./files/config.toml;
  environment.etc."codex/skills".source = managedSkills;
}
