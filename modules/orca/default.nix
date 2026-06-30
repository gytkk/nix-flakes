{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  themeExports,
  isWSL ? false,
  ...
}:

let
  cfg = config.modules.orca;

  themeFile = themeExports.file "ghostty" "${cfg.theme}.conf";
  themeConfig = builtins.readFile themeFile;

  parseThemeLine =
    line:
    let
      trimmed = lib.trim line;
      match = builtins.match "([^=]+)=(.*)" trimmed;
    in
    if trimmed == "" || lib.hasPrefix "#" trimmed || match == null then
      null
    else
      {
        key = lib.trim (builtins.elemAt match 0);
        value = lib.trim (builtins.elemAt match 1);
      };

  themeEntries = builtins.filter (entry: entry != null) (
    builtins.map parseThemeLine (lib.splitString "\n" themeConfig)
  );

  directColorKeys = {
    background = "background";
    foreground = "foreground";
    "cursor-color" = "cursor";
    "cursor-text" = "cursorAccent";
    "selection-background" = "selectionBackground";
    "selection-foreground" = "selectionForeground";
  };

  directColorOverrides = builtins.listToAttrs (
    builtins.filter (entry: entry != null) (
      builtins.map (
        entry:
        if builtins.hasAttr entry.key directColorKeys then
          {
            name = directColorKeys.${entry.key};
            inherit (entry) value;
          }
        else
          null
      ) themeEntries
    )
  );

  paletteColorKeys = {
    "0" = "black";
    "1" = "red";
    "2" = "green";
    "3" = "yellow";
    "4" = "blue";
    "5" = "magenta";
    "6" = "cyan";
    "7" = "white";
    "8" = "brightBlack";
    "9" = "brightRed";
    "10" = "brightGreen";
    "11" = "brightYellow";
    "12" = "brightBlue";
    "13" = "brightMagenta";
    "14" = "brightCyan";
    "15" = "brightWhite";
  };

  parsePaletteEntry =
    entry:
    let
      match = builtins.match "([0-9]+)=(#[0-9a-fA-F]+)" entry.value;
      index = if match == null then null else builtins.elemAt match 0;
    in
    if entry.key != "palette" || match == null || !(builtins.hasAttr index paletteColorKeys) then
      null
    else
      {
        name = paletteColorKeys.${index};
        value = builtins.elemAt match 1;
      };

  paletteColorOverrides = builtins.listToAttrs (
    builtins.filter (entry: entry != null) (builtins.map parsePaletteEntry themeEntries)
  );

  terminalColorOverrides = directColorOverrides // paletteColorOverrides;
  terminalDividerColor = terminalColorOverrides.selectionBackground or "#474747";
  terminalThemeId = "ghostty:${cfg.theme}";
  terminalThemeSelection = "custom:${terminalThemeId}";
  terminalThemeName = if cfg.theme == "vira-graphene" then "Vira Graphene" else cfg.theme;
  terminalTheme = {
    id = terminalThemeId;
    name = terminalThemeName;
    source = "ghostty";
    mode = "dark";
    terminal = terminalColorOverrides;
    importedAt = "2026-06-29T00:00:00.000Z";
    sourceLabel = "themes/exports/ghostty/${cfg.theme}.conf";
  };

  themeSettings = {
    terminalThemeDark = terminalThemeSelection;
    terminalThemeLight = terminalThemeSelection;
    terminalCustomThemes = [ terminalTheme ];
    terminalDividerColorDark = terminalDividerColor;
    terminalDividerColorLight = terminalDividerColor;
    terminalUseSeparateLightTheme = false;
    inherit terminalColorOverrides;
  };

  defaultSettings = {
    terminalFontSize = 12;
    terminalFontFamily = ''JetBrains Mono", "Sarasa Mono CL", "D2Coding'';
    terminalFontWeight = 400;
    terminalLineHeight = 1;
    terminalLigatures = "auto";
    terminalCursorStyle = "bar";
    terminalCursorStyleDefaultedToBlock = false;
    terminalCursorBlink = true;
    terminalBackgroundOpacity = 1;
    terminalInactivePaneOpacity = 0.9;
    terminalActivePaneOpacity = 1;
  }
  // themeSettings
  // lib.optionalAttrs isWSL {
    terminalWindowsShell = "wsl.exe";
    terminalWindowsWslDistro = "Ubuntu";
    localWindowsRuntimeDefault = {
      kind = "wsl";
      distro = "Ubuntu";
    };
  };

  windowsRoamingPath = "/mnt/c/Users/${cfg.windowsUsername}/AppData/Roaming";
  windowsOrcaDataPath = "${windowsRoamingPath}/orca/orca-data.json";
  darwinOrcaDataPath = "${homeDirectory}/Library/Application Support/orca/orca-data.json";
  orcaMergeFilter = ./files/merge-orca-data.jq;

  orcaDataPatch = {
    settings = cfg.settings;
    ui = cfg.ui;
  };

  orcaDataPatchFile = pkgs.writeText "orca-data-patch.json" (builtins.toJSON orcaDataPatch);

  mergeOrcaDataScript = ''
    if [ ! -f "$orca_data" ]; then
      echo "Skipping Orca $orca_target config: $orca_data does not exist"
      exit 0
    fi

    if [ ! -f "$orca_data.pre-nix-orca.bak" ]; then
      cp "$orca_data" "$orca_data.pre-nix-orca.bak"
    fi

    tmp="$orca_data.tmp.$$"
    if ${pkgs.jq}/bin/jq --slurpfile patch "${orcaDataPatchFile}" \
      -f "${orcaMergeFilter}" "$orca_data" > "$tmp"; then
      if cmp -s "$tmp" "$orca_data"; then
        rm -f "$tmp"
      else
        mv "$tmp" "$orca_data"
      fi
    else
      rm -f "$tmp"
      exit 1
    fi
  '';

  darwinActivationScript = ''
    orca_target="macOS"
    orca_data="${darwinOrcaDataPath}"

    if command -v pgrep >/dev/null 2>&1 && pgrep -x Orca >/dev/null 2>&1; then
      echo "Cannot update Orca settings while Orca is running. Quit Orca and rerun home-manager switch to apply terminal settings." >&2
      exit 1
    fi

    ${mergeOrcaDataScript}
  '';

  windowsActivationScript = ''
    roaming_dir="${windowsRoamingPath}"
    if [ ! -d "$roaming_dir" ]; then
      echo "Skipping Orca Windows config: $roaming_dir does not exist"
      exit 0
    fi

    orca_target="Windows"
    orca_data="${windowsOrcaDataPath}"

    if command -v powershell.exe >/dev/null 2>&1; then
      if powershell.exe -NoProfile -Command "if (Get-Process -Name Orca -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" >/dev/null 2>&1; then
        echo "Cannot update Orca settings while Orca is running. Quit Orca and rerun home-manager switch to apply terminal settings." >&2
        exit 1
      fi
    fi

    ${mergeOrcaDataScript}
  '';
in
{
  options.modules.orca = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Orca settings integration.";
    };

    windowsUsername = lib.mkOption {
      type = lib.types.str;
      default = username;
      description = "Windows user profile name used when configuring Orca from WSL.";
    };

    theme = lib.mkOption {
      type = lib.types.str;
      default = "vira-graphene";
      description = "Theme export name used to build Orca terminal theme settings.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = defaultSettings;
      description = "Values to merge into Orca's settings object.";
    };

    ui = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Values to merge into Orca's ui object.";
    };

    applyWindowsSettings = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "When running under WSL, merge settings into Windows Orca data.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf (isWSL && cfg.applyWindowsSettings) {
        home.activation.orcaWindowsConfig = lib.hm.dag.entryAfter [
          "writeBoundary"
        ] windowsActivationScript;
      })

      (lib.mkIf pkgs.stdenv.isDarwin {
        home.activation.orcaDarwinConfig = lib.hm.dag.entryAfter [
          "writeBoundary"
        ] darwinActivationScript;
      })
    ]
  );
}
