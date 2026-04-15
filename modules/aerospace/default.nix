{
  config,
  lib,
  pkgs,
  flakeDirectory,
  ...
}:

let
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/aerospace/${path}";
in
lib.mkIf pkgs.stdenv.isDarwin {
  xdg.configFile."aerospace/aerospace.toml".source = mkSymlink "files/aerospace.toml";
}
