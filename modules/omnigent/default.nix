{
  config,
  pkgs,
  lib,
  flakeDirectory,
  ...
}:

let
  cfg = config.modules.omnigent;
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/omnigent/${path}";
in
{
  options.modules.omnigent = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the omnigent CLI and the gytkk workspace orchestrator agent";
    };
  };

  config = lib.mkIf cfg.enable {
    # omnigent is built from source via uv2nix (see packages/omnigent). This is
    # the API-only build: terminal/CLI orchestration works; there is no
    # localhost:6767 browser UI (bundling the npm web UI is a future follow-up).
    home.packages = [ pkgs.omnigent ];

    # nix pins the version, so silence omnigent's per-release update notice.
    home.sessionVariables.OMNIGENT_NO_UPDATE_CHECK = "1";

    # The gytkk workspace orchestrator agent, kept under version control here and
    # exposed at a stable path. Run it with:  omni run ~/.omnigent/agents/gytkk
    home.file.".omnigent/agents/gytkk".source = mkSymlink "agents/gytkk";
  };
}
