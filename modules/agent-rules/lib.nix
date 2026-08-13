{ lib, pkgs }:

let
  sharedRuleFiles = [
    ./AGENTS.md
    ./rules/WRITING.md
  ];
in
{
  render =
    name: agentRuleFiles:
    pkgs.writeText name (
      lib.concatMapStringsSep "\n\n" builtins.readFile (sharedRuleFiles ++ agentRuleFiles)
    );
}
