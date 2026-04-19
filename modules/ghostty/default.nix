{
  config,
  themeExports,
  ...
}:

let
  ghosttyConfig =
    builtins.replaceStrings
      [ ''theme = "__COMMON_THEME__.conf"'' ]
      [ ''theme = "${config.modules.commonTheme}.conf"'' ]
      (builtins.readFile ./files/config);
in
{
  xdg.configFile."ghostty/themes".source = themeExports.dir "ghostty";
  xdg.configFile."ghostty/config".text = ghosttyConfig;
}
