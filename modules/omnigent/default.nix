{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.modules.omnigent;
in
{
  options.modules.omnigent = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the omnigent CLI";
    };
  };

  config = lib.mkIf cfg.enable {
    # omnigent is built from source via uv2nix (see packages/omnigent). This is
    # the API-only build: terminal/CLI orchestration works; there is no
    # localhost:6767 browser UI (bundling the npm web UI is a future follow-up).
    home.packages = [ pkgs.omnigent ];

    # nix pins the version, so silence omnigent's per-release update notice.
    home.sessionVariables.OMNIGENT_NO_UPDATE_CHECK = "1";
  };
}
