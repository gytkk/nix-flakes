{
  config,
  flakeDirectory,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.herdr;
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/herdr/${path}";
in
{
  options.modules.herdr.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Herdr module";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.herdr ];

    xdg.configFile."herdr/config.toml".source = mkSymlink "files/config.toml";
  };
}
