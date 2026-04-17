{
  config,
  flakeDirectory,
  ...
}:

let
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/rio/${path}";
in
{
  xdg.configFile."rio/config.toml".source = mkSymlink "files/config.toml";
  xdg.configFile."rio/themes".source = mkSymlink "themes";
}
