{
  config,
  pkgs,
  themeExports,
  ...
}:

let
  generatedThemes = config.lib.file.mkOutOfStoreSymlink (themeExports.mutableDir "zellij");
  zellaudeVersion = "0.5.0";
  zellaudeWasm = pkgs.fetchurl {
    url = "https://github.com/ishefi/zellaude/releases/download/v${zellaudeVersion}/zellaude.wasm";
    hash = "sha256-HWtHklUKLQgzpr8ndxhOz5urQWwXi0nDF7XhsM2ELCQ=";
  };
  configPath = if pkgs.stdenv.isDarwin then ./files/config.darwin.kdl else ./files/config.linux.kdl;
  configTemplate = builtins.readFile configPath;
  renderedConfig = pkgs.writeText "zellij-config.kdl" (
    builtins.replaceStrings [ ''theme "one-half-light"'' ] [ ''theme "${config.modules.commonTheme}"'' ]
      configTemplate
  );
in

{
  home.packages = [ pkgs.zellij ];

  xdg.configFile."zellij/config.kdl".source = renderedConfig;
  xdg.configFile."zellij/layouts/zellaude.kdl".source = ./files/layouts/zellaude.kdl;
  xdg.configFile."zellij/plugins/zellaude.wasm".source = zellaudeWasm;
  xdg.configFile."zellij/plugins/zellaude-hook.sh" = {
    source = ./files/zellaude-hook.sh;
    executable = true;
  };
  xdg.configFile."zellij/themes".source = generatedThemes;
}
