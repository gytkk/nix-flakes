{ lib, pkgs }:

let
  operatingRules = ./rules/OPERATING.md;
  sharedRuleFiles = [
    ./AGENTS.md
    ./rules/WRITING.md
  ];
  renderFiles =
    name: ruleFiles: pkgs.writeText name (lib.concatMapStringsSep "\n\n" builtins.readFile ruleFiles);
in
{
  inherit operatingRules;

  render =
    name: agentRuleFiles: renderFiles name ([ operatingRules ] ++ sharedRuleFiles ++ agentRuleFiles);

  renderWithoutOperating = name: agentRuleFiles: renderFiles name (sharedRuleFiles ++ agentRuleFiles);
}
