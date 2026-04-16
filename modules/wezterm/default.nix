{
  config,
  flakeDirectory,
  ...
}:

{
  xdg.configFile."wezterm/wezterm.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/wezterm/files/wezterm.lua";
}
