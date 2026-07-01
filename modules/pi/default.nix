{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.pi;
in
{
  options.modules.pi.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Pi coding agent CLI";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.pi
    ];
  };
}
