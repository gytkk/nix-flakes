{
  config,
  lib,
  pkgs,
  ...
}:

let
  ccusage = pkgs.buildNpmPackage rec {
    pname = "ccusage";
    version = "latest";

    src = pkgs.fetchFromGitHub {
      owner = "ryoppippi";
      repo = "ccusage";
      rev = "main";
      sha256 = lib.fakeSha256;
    };

    npmDepsHash = lib.fakeSha256;

    meta = with lib; {
      description = "Claude Code usage tracking utility";
      homepage = "https://github.com/ryoppippi/ccusage";
      license = licenses.mit;
      maintainers = [ ];
    };
  };
in
{
  home.packages = [ ccusage ];
}