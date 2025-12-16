{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  # Rosé Pine 테마
  xdg.configFile."ghostty/themes/rose-pine".source = "${inputs.rose-pine-ghostty}/dist";
  # Catppuccin 테마
  xdg.configFile."ghostty/themes/catppuccin".source = "${inputs.catppuccin-ghostty}/themes";

  xdg.configFile."ghostty/config".text = ''
    auto-update = check

    theme = catppuccin/catppuccin-latte.conf

    background-opacity = 0.95

    font-size = 13
    font-family = "JetBrainsMono Nerd Font Mono"

    # CJK Fallback
    font-family = "Sarasa Mono CL"

    window-padding-balance = true

    link-url = true
  '';
}
