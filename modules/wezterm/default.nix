{
  config,
  lib,
  pkgs,
  username,
  flakeDirectory,
  themeExports,
  isWSL ? false,
  ...
}:

let
  windowsWeztermConfigPath = "/mnt/c/Users/${username}/.config/wezterm";
  windowsWeztermBridgePath = "/mnt/c/Users/${username}/.wezterm.lua";
  weztermThemeExportsPath = themeExports.mutableDir "wezterm";
  weztermThemeExports = config.lib.file.mkOutOfStoreSymlink weztermThemeExportsPath;
  renderedConfig = pkgs.writeText "wezterm.lua" (
    builtins.replaceStrings [ "__COMMON_THEME__" ] [ config.modules.commonTheme ] (
      builtins.readFile ./files/wezterm.lua
    )
  );

  wslActivationScript = ''
    mkdir -p "${windowsWeztermConfigPath}"
    mkdir -p "${windowsWeztermConfigPath}/themes"

    if [ -f "${windowsWeztermConfigPath}/wezterm.lua" ] && [ ! -f "${windowsWeztermConfigPath}/wezterm.lua.bak" ]; then
      cp "${windowsWeztermConfigPath}/wezterm.lua" "${windowsWeztermConfigPath}/wezterm.lua.bak"
      echo "Backed up existing Windows WezTerm config to wezterm.lua.bak"
    fi

    if [ -f "${windowsWeztermBridgePath}" ] && [ ! -f "${windowsWeztermBridgePath}.bak" ]; then
      cp "${windowsWeztermBridgePath}" "${windowsWeztermBridgePath}.bak"
      echo "Backed up existing Windows WezTerm bridge to .wezterm.lua.bak"
    fi

    cp "${renderedConfig}" "${windowsWeztermConfigPath}/wezterm.lua"
    cp "${flakeDirectory}/modules/wezterm/files/windows-bridge.lua" "${windowsWeztermBridgePath}"
    rm -f "${windowsWeztermConfigPath}/themes/"*.lua
    for theme in "${weztermThemeExportsPath}"/*.lua; do
      [ -f "$theme" ] || continue
      cp -f "$theme" "${windowsWeztermConfigPath}/themes/$(basename "$theme")"
    done

    echo "WezTerm config deployed to Windows:"
    echo "  - Config: ${windowsWeztermConfigPath}"
    echo "  - Themes: ${windowsWeztermConfigPath}/themes"
    echo "  - Bridge: ${windowsWeztermBridgePath}"
  '';
in
{
  xdg.configFile."wezterm/wezterm.lua".source = renderedConfig;
  xdg.configFile."wezterm/themes".source = weztermThemeExports;
}
// lib.optionalAttrs isWSL {
  home.activation.weztermWindowsConfig = lib.hm.dag.entryAfter [
    "writeBoundary"
  ] wslActivationScript;
}
