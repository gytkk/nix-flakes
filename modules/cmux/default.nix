{
  config,
  lib,
  pkgs,
  themeExports,
  ...
}:

let
  cfg = config.modules.cmux;
  cmuxSchema = "https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux.schema.json";
  zedThemeDoc = builtins.fromJSON (
    builtins.readFile (themeExports.file "zed" "${config.modules.commonTheme}.json")
  );
  zedTheme = builtins.head zedThemeDoc.themes;
  appearance =
    if
      builtins.elem zedTheme.appearance [
        "dark"
        "light"
      ]
    then
      zedTheme.appearance
    else
      "system";
  cmuxSettings = {
    "$schema" = cmuxSchema;
    schemaVersion = 1;

    app = {
      inherit appearance;
      appIcon = "automatic";
      workspaceInheritWorkingDirectory = true;
      confirmQuit = "always";
    };

    terminal = {
      showScrollBar = true;
      copyOnSelect = false;
      autoResumeAgentSessions = true;
      textBoxMaxLines = 10;
    };

    browser = {
      theme = appearance;
      openTerminalLinksInCmuxBrowser = true;
      interceptTerminalOpenCommandInCmuxBrowser = true;
    };

    sidebarAppearance = {
      matchTerminalBackground = true;
      tintColor = "#000000";
      tintOpacity = 0;
    };

    automation = {
      suppressSubagentNotifications = true;
    };
  };
in
{
  options.modules.cmux = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.isDarwin;
      description = "Enable cmux app settings managed by Home Manager";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."cmux/cmux.json".text = builtins.toJSON cmuxSettings;
  };
}
