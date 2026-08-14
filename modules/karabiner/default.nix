{
  config,
  lib,
  pkgs,
  flakeDirectory,
  ...
}:

let
  cfg = config.modules.karabiner;
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/karabiner/${path}";
in
{
  options.modules.karabiner.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Karabiner-Elements configuration";
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    xdg.configFile."karabiner/karabiner.json".source = mkSymlink "files/karabiner.json";
  };
}
