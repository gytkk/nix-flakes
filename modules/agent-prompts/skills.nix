{
  inputs,
  lib,
  pkgs,
}:

let
  upstream = inputs.mattpocock-skills;
  pluginManifest = builtins.fromJSON (builtins.readFile "${upstream}/.claude-plugin/plugin.json");
  officialPaths =
    pluginManifest.skills or (throw "mattpocock-skills plugin manifest has no skills list");
  mkSkill =
    relativePath:
    let
      normalizedPath = lib.removePrefix "./" relativePath;
    in
    {
      name = builtins.baseNameOf normalizedPath;
      value = upstream + "/${normalizedPath}";
    };
  official = builtins.listToAttrs (map mkSkill officialPaths);
  officialNames = map (path: builtins.baseNameOf (lib.removePrefix "./" path)) officialPaths;

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
assert pluginManifest.name == "mattpocock-skills";
assert builtins.length officialNames == builtins.length (lib.unique officialNames);
assert claudeOnlyCollisions == [ ];
{
  inherit claudeOnly mkSkillFarm official;
  shared = official;
  claude = official // claudeOnly;
}
