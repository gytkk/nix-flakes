{ pkgs, ... }:

{
  programs.zellij = {
    enable = true;

    settings = {
      theme = "one-half-light";
      show_startup_tips = false;
    };

    extraConfig = ''
      keybinds {
          shared_except "tmux" "locked" {
              unbind "Ctrl b"
          }
      }
    '';
  };

  xdg.configFile."zellij/plugins/zellij_sidebar.wasm".source =
    "${pkgs.zellij-sidebar}/share/zellij/plugins/zellij_sidebar.wasm";

  xdg.configFile."zellij/themes/one-half-light.kdl".source = ./files/one-half-light.kdl;

}
