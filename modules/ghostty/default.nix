{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  xdg.configFile."ghostty/themes".source = "${inputs.catppuccin-ghostty}/themes";

  xdg.configFile."ghostty/config".text = ''
    auto-update = check

    theme = catppuccin-latte.conf

    background-opacity = 0.95

    font-size = 13
    font-family = "JetBrainsMono Nerd Font Mono"

    # CJK Fallback
    font-family = "Sarasa Mono CL"

    window-padding-balance = true

    link-url = true
  '';
}
