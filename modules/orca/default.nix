{
  config,
  lib,
  pkgs,
  themeExports,
  ...
}:

let
  cfg = config.modules.orca;
  dataTarget =
    if cfg.dataFile == null then
      "${config.home.homeDirectory}/Library/Application Support/orca"
    else
      cfg.dataFile;
  theme = builtins.fromJSON (
    builtins.readFile (themeExports.file "orca" "${config.modules.commonTheme}.json")
  );
  appearance = builtins.fromJSON (builtins.readFile ./files/appearance.json);
  patchFile = pkgs.writeText "orca-settings.json" (
    builtins.toJSON {
      settings = appearance // {
        theme = theme.mode;
        terminalThemeDark = "custom:${theme.id}";
        terminalThemeLight = "custom:${theme.id}";
        terminalUseSeparateLightTheme = false;
        terminalCustomThemes = [ theme ];
        terminalColorOverrides = { };
      };
    }
  );
  applySettings = pkgs.writeShellApplication {
    name = "orca-apply-settings";
    runtimeInputs = with pkgs; [
      coreutils
      jq
    ];
    text = ''
      if [ "$#" -ne 0 ]; then
        echo "Usage: orca-apply-settings" >&2
        exit 2
      fi
      exec ${pkgs.bash}/bin/bash ${./files/apply-settings.sh} \
        ${patchFile} ${lib.escapeShellArg dataTarget} ${./files/merge-settings.jq}
    '';
  };
in
{
  options.modules.orca = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Manage Orca appearance settings on macOS.";
    };
    dataFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Override the Orca data path; null resolves the active macOS profile.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isDarwin;
        message = "modules.orca currently supports macOS only.";
      }
    ];
    xdg.configFile."orca/settings.json".source = patchFile;
    home.packages = [ applySettings ];
  };
}
