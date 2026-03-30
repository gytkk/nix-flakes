{ ... }:

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

  xdg.configFile."zellij/themes/ayu-light.kdl".source = ./files/ayu-light.kdl;

}
