{
  config,
  lib,
  pkgs,
  ...
}:

{
  xdg.configFile."ghostty/config".text = ''
    auto-update = check

    theme = OneHalfLight
    # theme = Monokai Pro Light
    # theme = Material

    background-opacity = 0.95

    font-size = 13
    font-family = "JetBrainsMono Nerd Font Mono"

    # CJK Fallback
    font-family = "Sarasa Mono CL"

    window-padding-balance = true

    link-url = true
  '';
}
