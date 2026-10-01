{
  pkgs,
  isDarwin ? pkgs.stdenv.isDarwin,
}:
let
  callPackage = pkgs.lib.callPackageWith (
    pkgs
    // {
      mkTarballCli = pkgs.callPackage ./lib/mk-tarball-cli.nix { };
    }
  );
in
rec {
  agent-browser = callPackage ./agent-browser/package.nix { };
  cf = callPackage ./cf/package.nix { };
  claude-code = callPackage ./claude-code/package.nix { };
  codex = callPackage ./codex/package.nix { };
  codexbar = callPackage ./codexbar/package.nix { };
  databricks-cli = callPackage ./databricks-cli/package.nix { };
  herdr = callPackage ./herdr/package.nix { };
  herdr-annotate = callPackage ./herdr-annotate/package.nix { };
  herdr-auto-title = callPackage ./herdr-auto-title/package.nix { };
  notion-cli = callPackage ./notion-cli/package.nix { };
  ntn = notion-cli;
  pi = callPackage ./pi/package.nix { };
  pup = callPackage ./pup/package.nix { };
}
// (if isDarwin then { gksdud = callPackage ./gksdud/package.nix { }; } else { })
