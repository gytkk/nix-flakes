{
  config,
  lib,
  pkgs,
  flakeDirectory,
  ...
}:

let
  cfg = config.modules.cmux;
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/cmux/${path}";
in
{
  options.modules.cmux = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.isDarwin;
      description = "Enable cmux app settings managed by Home Manager";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."cmux/cmux.json".source = mkSymlink "files/cmux.json";
  };
}
