{ pkgs }:
runtime:

assert builtins.elem runtime [
  "openclaw"
  "codex"
  "claude"
  "pi"
];
pkgs.runCommand "agent-core-${runtime}" { nativeBuildInputs = [ pkgs.agent-core ]; } ''
  agent-core render --runtime ${pkgs.lib.escapeShellArg runtime} --output "$out"
''
