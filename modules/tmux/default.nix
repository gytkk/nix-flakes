{
  config,
  flakeDirectory,
  pkgs,
  ...
}:

let
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/tmux/${path}";
  tmuxWrapper = pkgs.writeShellScriptBin "tmux" ''
    if [ "$#" -eq 0 ] && [ -t 0 ] && [ -t 1 ] && [ -z "''${TMUX:-}" ]; then
      exec ${pkgs.bash}/bin/bash ${flakeDirectory}/modules/tmux/files/tmux-session-manager.sh ${pkgs.tmux}/bin/tmux
    fi

    exec ${pkgs.tmux}/bin/tmux "$@"
  '';
in
{
  home.packages = [
    tmuxWrapper
  ];

  xdg.configFile."tmux/tmux.conf".source = mkSymlink "files/tmux.conf";
}
