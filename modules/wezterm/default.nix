{
  config,
  flakeDirectory,
  ...
}:

{
  home.file.".wezterm.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/wezterm/files/wezterm.lua";
}
