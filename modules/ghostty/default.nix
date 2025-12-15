{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  xdg.configFile."ghostty/themes".source = "${inputs.rose-pine-ghostty}/dist";

  xdg.configFile."ghostty/config".text = ''
    auto-update = check

    theme = rose-pine-dawn

    background-opacity = 0.95

    font-size = 13
    font-family = "JetBrainsMono Nerd Font Mono"

    # CJK Fallback
    font-family = "Sarasa Mono CL"

    window-padding-balance = true

    link-url = true
  '';
}
