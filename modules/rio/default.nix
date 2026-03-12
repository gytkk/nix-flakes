{
  config,
  flakeDirectory,
  ...
}:

{
  # config → repo 파일로 직접 symlink (mutable)
  xdg.configFile."rio/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/rio/files/config.toml";
}
