{
  config,
  ...
}:

let
  ghosttyConfig =
    builtins.replaceStrings
      [ ''theme = "one-half-light"'' ]
      [ ''theme = "${config.modules.commonTheme}"'' ]
      (builtins.readFile ./files/config);
in
{
  xdg.configFile."ghostty/themes".source = ../../themes/exports/ghostty;
  xdg.configFile."ghostty/config".text = ghosttyConfig;
}
