{
  config,
  ...
}:

let
  ghosttyConfig =
    builtins.replaceStrings
      [ ''theme = "one-half-light.conf"'' ]
      [ ''theme = "${config.modules.commonTheme}.conf"'' ]
      (builtins.readFile ./files/config);
in
{
  xdg.configFile."ghostty/themes".source = ../../themes/exports/ghostty;
  xdg.configFile."ghostty/config".text = ghosttyConfig;
}
