{
  config,
  flakeDirectory,
  ...
}:

let
  generatedThemes = config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/themes/exports/ghostty";
  ghosttyConfig = builtins.replaceStrings [ ''theme = "one-half-light"'' ] [ ''theme = "${config.modules.commonTheme}"'' ] (
    builtins.readFile (flakeDirectory + "/modules/ghostty/files/config")
  );
in
{
  xdg.configFile."ghostty/themes".source = generatedThemes;
  xdg.configFile."ghostty/config".text = ghosttyConfig;
}
