{
  config,
  themeExports,
  ...
}:

let
  ghosttyConfig = builtins.replaceStrings [ "__COMMON_THEME__" ] [ "${config.modules.commonTheme}" ] (
    builtins.readFile ./files/config
  );
in
{
  xdg.configFile."ghostty/themes".source = themeExports.dir "ghostty";
  xdg.configFile."ghostty/config".text = ghosttyConfig;
}
