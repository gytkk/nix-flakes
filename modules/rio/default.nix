{
  config,
  flakeDirectory,
  ...
}:

{
  xdg.configFile."rio/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/rio/files/config.toml";
}
