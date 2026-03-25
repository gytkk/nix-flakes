{
  config,
  flakeDirectory,
  ...
}:

{
  # config → repo 파일로 직접 symlink (mutable)
  xdg.configFile."kitty/kitty.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/kitty/files/kitty.conf";
}
