{
  config,
  flakeDirectory,
  pkgs,
  themeExports,
  ...
}:

let
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/tmux/${path}";
  generatedThemes = themeExports.mutableDirLink config.lib.file "tmux";
  selectedTheme =
    themeExports.mutableFileLink config.lib.file "tmux"
      "${config.modules.commonTheme}.conf";
  tmuxSessionManager = pkgs.writeShellScriptBin "tm" ''
    if [ "$#" -eq 0 ] && [ -t 0 ] && [ -t 1 ] && [ -z "''${TMUX:-}" ]; then
      exec ${pkgs.bash}/bin/bash ${flakeDirectory}/modules/tmux/files/tmux-session-manager.sh ${pkgs.tmux}/bin/tmux ${pkgs.fzf}/bin/fzf
    fi

    exec ${pkgs.tmux}/bin/tmux "$@"
  '';
in
{
  home.packages = [
    pkgs.tmux
    tmuxSessionManager
  ];

  xdg.configFile = {
    "tmux/tmux.conf".source = mkSymlink "files/tmux.conf";
    "tmux/keybindings.conf".source = mkSymlink "files/keybindings.conf";
    "tmux/statusline.conf".source = mkSymlink "files/statusline.conf";
    "tmux/themes".source = generatedThemes;
    "tmux/theme.conf".source = selectedTheme;
  };
}
