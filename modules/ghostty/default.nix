{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # 두 테마 소스를 하나의 디렉토리로 병합
  combinedThemes = pkgs.symlinkJoin {
    name = "ghostty-themes";
    paths = [
      "${inputs.rose-pine-ghostty}/dist"
      "${inputs.catppuccin-ghostty}/themes"
    ];
  };
in
{
  xdg.configFile."ghostty/themes".source = combinedThemes;

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
