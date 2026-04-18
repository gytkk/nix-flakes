{
  config,
  flakeDirectory,
  pkgs,
  ...
}:

let
  generatedThemes = config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/themes/exports/rio";
  configTemplate = builtins.readFile ./files/config.toml;
  renderedConfig = pkgs.writeText "rio-config.toml" (
    builtins.replaceStrings
      [ ''theme = "one-half-light"'' ]
      [ ''theme = "${config.modules.commonTheme}"'' ]
      configTemplate
  );
in
{
  xdg.configFile."rio/config.toml".source = renderedConfig;
  xdg.configFile."rio/themes".source = generatedThemes;
}
