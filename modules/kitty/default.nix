{
  config,
  flakeDirectory,
  ...
}:

{
  xdg.configFile."kitty/kitty.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/kitty/files/kitty.conf";
}
