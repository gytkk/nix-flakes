{
  config,
  lib,
  pkgs,
  themeExports,
  ...
}:

let
  generatedThemes = config.lib.file.mkOutOfStoreSymlink (themeExports.mutableDir "zellij");
  configTemplate = builtins.readFile ./files/config.kdl;
  platformSettings = lib.optionalString pkgs.stdenv.isDarwin ''
    copy_command "pbcopy"
  '';
  renderedConfig = pkgs.writeText "zellij-config.kdl" (
    builtins.replaceStrings
      [
        "__PLATFORM_SETTINGS__"
        "__COMMON_THEME__"
      ]
      [
        platformSettings
        config.modules.commonTheme
      ]
      configTemplate
  );
  zellijWrapper = pkgs.writeShellScriptBin "zellij" ''
    if [ "$#" -eq 0 ]; then
      exec ${pkgs.zellij}/bin/zellij --layout welcome
    fi

    exec ${pkgs.zellij}/bin/zellij "$@"
  '';
in

{
  home.packages = [ zellijWrapper ];

  xdg.configFile."zellij/config.kdl".source = renderedConfig;
  xdg.configFile."zellij/themes".source = generatedThemes;
}
