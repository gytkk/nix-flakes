{ pkgs }:
{
  outputHash ? null,
  runtime,
  runtimeSkillRoots ? [ ],
}:

let
  runtimeSkillArgs = pkgs.lib.concatMapStringsSep " " (
    root: "--runtime-skill-root ${pkgs.lib.escapeShellArg "${root}"}"
  ) runtimeSkillRoots;
in

assert builtins.elem runtime [
  "openclaw"
  "codex"
  "claude"
  "pi"
];
pkgs.runCommand "agent-core-${runtime}"
  (
    {
      nativeBuildInputs = with pkgs; [ agent-core ];
    }
    // pkgs.lib.optionalAttrs (outputHash != null) {
      inherit outputHash;
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
    }
  )
  ''
    agent-core render \
      --runtime ${pkgs.lib.escapeShellArg runtime} \
      ${runtimeSkillArgs} \
      --output "$out"
  ''
