{
  config,
  pkgs,
  themeExports,
  ...
}:

let
  generatedThemes = config.lib.file.mkOutOfStoreSymlink (themeExports.mutableDir "zellij");
  configPath = if pkgs.stdenv.isDarwin then ./files/config.darwin.kdl else ./files/config.linux.kdl;
  configTemplate = builtins.readFile configPath;
  renderedConfig = pkgs.writeText "zellij-config.kdl" (
    builtins.replaceStrings [ ''theme "one-half-light"'' ] [ ''theme "${config.modules.commonTheme}"'' ]
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
