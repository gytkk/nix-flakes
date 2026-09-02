{ pkgs, ... }:

let
  agentCoreOutput = import ../../agent-core/nix/render.nix { inherit pkgs; } { runtime = "codex"; };
in
{
  environment.etc."codex/config.toml".source = ./files/config.toml;
  environment.etc."codex/skills".source = "${agentCoreOutput}/skills";
}
