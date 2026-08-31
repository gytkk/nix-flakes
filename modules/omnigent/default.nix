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
    # omnigent는 packages/omnigent에서 uv2nix로 빌드하며
    # 별도로 빌드한 브라우저 UI도 Python 패키지에 포함한다.
    home.packages = [ pkgs.omnigent ];

    # nix pins the version, so silence omnigent's per-release update notice.
    home.sessionVariables.OMNIGENT_NO_UPDATE_CHECK = "1";
  };
}
