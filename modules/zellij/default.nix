{
  config,
  pkgs,
  flakeDirectory,
  ...
}:

let
  mkModuleSymlink =
    path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/zellij/${path}";
  generatedThemes = config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/themes/exports/zellij";
  configPath = if pkgs.stdenv.isDarwin then "files/config.darwin.kdl" else "files/config.linux.kdl";
in

{
  home.packages = [ pkgs.zellij ];

  xdg.configFile."zellij/config.kdl".source = mkModuleSymlink configPath;
  xdg.configFile."zellij/themes".source = generatedThemes;
}
