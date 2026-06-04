{
  config,
  flakeDirectory,
  pkgs,
  ...
}:

let
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/tmux/${path}";
in
{
  home.packages = [
    pkgs.tmux
  ];

  xdg.configFile."tmux/tmux.conf".source = mkSymlink "files/tmux.conf";
}
