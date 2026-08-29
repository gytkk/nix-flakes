{
  config,
  lib,
  pkgs,
  homeDirectory,
  ...
}:
let
  cfg = config.modules.qmd;
  qmdPackage = pkgs.callPackage ../../packages/qmd/package.nix { };
in
{
  options.modules.qmd = {
    enable = lib.mkEnableOption "QMD access to shared agent memory";

    workspaceRoot = lib.mkOption {
      type = lib.types.str;
      default = "${homeDirectory}/workspace/ps";
      description = "Workspace containing the canonical agent memory files.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.workspaceRoot;
        message = "modules.qmd.workspaceRoot must be an absolute path.";
      }
    ];

    home.packages = [ qmdPackage ];

    xdg.configFile."qmd/index.yml".text = ''
      collections:
        workspace-user:
          path: ${builtins.toJSON cfg.workspaceRoot}
          pattern: USER.md
        workspace-memory:
          path: ${builtins.toJSON cfg.workspaceRoot}
          pattern: MEMORY.md
        workspace-daily:
          path: ${builtins.toJSON "${cfg.workspaceRoot}/memory"}
          pattern: "**/*.md"
    '';
  };
}
