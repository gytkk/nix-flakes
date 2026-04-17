{
  config,
  flakeDirectory,
  ...
}:

let
  mkModuleSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/rio/${path}";
  generatedThemes = config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/themes/exports/rio";
in
{
  xdg.configFile."rio/config.toml".source = mkModuleSymlink "files/config.toml";
  xdg.configFile."rio/themes".source = generatedThemes;
}
