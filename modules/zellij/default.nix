{
  config,
  pkgs,
  flakeDirectory,
  ...
}:

let
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/zellij/${path}";
  configPath = if pkgs.stdenv.isDarwin then "files/config.darwin.kdl" else "files/config.linux.kdl";
in

{
  programs.zellij.enable = true;

  xdg.configFile."zellij/config.kdl".source = mkSymlink configPath;
}
