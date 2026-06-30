{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  isWSL ? false,
  ...
}:

let
  cfg = config.modules.orca;

  defaultSettings = {
    terminalFontSize = 14;
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
