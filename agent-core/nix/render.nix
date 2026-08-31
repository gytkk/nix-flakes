{ pkgs }:
{
  outputHash ? null,
  runtime,
}:

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
      --output "$out"
  ''
