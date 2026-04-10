{ pkgs, ... }:

{
  programs.zellij = {
    enable = true;

    settings = {
      default_layout = "welcome";
      theme = "one-half-light";
      show_startup_tips = false;
    };

    # XXX: theme inlined as workaround for theme_dir not being picked up on startup
    # https://github.com/zellij-org/zellij/pull/4892
    extraConfig = builtins.readFile ./files/one-half-light.kdl + ''

      keybinds {
          shared_except "tmux" "locked" {
              unbind "Ctrl b"
          }
      }
    '';
  };
}
