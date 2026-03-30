{
  config,
  lib,
  ...
}:

{
  programs.zellij = {
    enable = true;

    settings = {
      theme = "ayu-light";
    };
  };

  programs.zsh.initContent = lib.mkAfter ''
    if [[ -o interactive ]] \
      && [[ -z "$ZELLIJ" ]] \
      && [[ -z "$TMUX" ]] \
      && [[ -z "$SSH_CONNECTION" ]] \
      && [[ -z "$SSH_CLIENT" ]] \
      && [[ -z "$SSH_TTY" ]] \
      && { [[ "$TERM_PROGRAM" == "ghostty" ]] || [[ "$TERM_PROGRAM" == "xterm-ghostty" ]] || [[ "$TERM" == "xterm-ghostty" ]] || [[ -n "$GHOSTTY_RESOURCES_DIR" ]]; }; then
      exec ${lib.getExe config.programs.zellij.package}
    fi
  '';
}
