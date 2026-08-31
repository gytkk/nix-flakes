{ pkgs, ... }:

let
  agentCoreOutput = import ../../agent-core/nix/render.nix { inherit pkgs; } {
    runtime = "codex";
    runtimeSkillRoots = [ ./skills ];
  };
in
{
  environment.etc."codex/managed_config.toml".source = ./files/config.toml;
  environment.etc."codex/skills".source = "${agentCoreOutput}/skills";
}
