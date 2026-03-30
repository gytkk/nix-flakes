{ pkgs, ... }:

{
  programs.zellij = {
    enable = true;

    settings = {
      theme = "ayu-light";
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

  xdg.configFile."zellij/themes/ayu-light.kdl".source = ./files/ayu-light.kdl;

}
