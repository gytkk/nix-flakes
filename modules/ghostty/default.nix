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

    # Tomorrow Light theme (by Chris Kempson)
    background = #ffffff
    foreground = #4d4d4c

    # ANSI colors (normal)
    palette = 0=#1d1f21
    palette = 1=#c82829
    palette = 2=#718c00
    palette = 3=#eab700
    palette = 4=#4271ae
    palette = 5=#8959a8
    palette = 6=#3e999f
    palette = 7=#4d4d4c

    # ANSI colors (bright)
    palette = 8=#8e908c
    palette = 9=#c82829
    palette = 10=#718c00
    palette = 11=#eab700
    palette = 12=#4271ae
    palette = 13=#8959a8
    palette = 14=#3e999f
    palette = 15=#1d1f21

    background-opacity = 0.95

    font-size = 13
    font-family = "JetBrainsMono Nerd Font Mono"

    # CJK Fallback
    font-family = "Sarasa Mono CL"

    window-padding-balance = true

    link-url = true
  '';
}
