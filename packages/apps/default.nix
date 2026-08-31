{ pkgs }:

{
  agent-browser = pkgs.callPackage ./agent-browser/package.nix { };
  claude-code = pkgs.callPackage ./claude-code/package.nix { };
  codex = pkgs.callPackage ./codex/package.nix { };
  herdr = pkgs.callPackage ./herdr/package.nix { };
  kimi-code = pkgs.callPackage ./kimi-code/package.nix { };
  opencode = pkgs.callPackage ./opencode/package.nix { };
  pi = pkgs.callPackage ./pi/package.nix { };
}
