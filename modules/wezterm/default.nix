{
  config,
  lib,
  username,
  flakeDirectory,
  isWSL ? false,
  ...
}:

let
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/wezterm/${path}";

  windowsWeztermConfigPath = "/mnt/c/Users/${username}/.config/wezterm";
  windowsWeztermBridgePath = "/mnt/c/Users/${username}/.wezterm.lua";

  wslActivationScript = ''
    mkdir -p "${windowsWeztermConfigPath}"

    if [ -f "${windowsWeztermConfigPath}/wezterm.lua" ] && [ ! -f "${windowsWeztermConfigPath}/wezterm.lua.bak" ]; then
      cp "${windowsWeztermConfigPath}/wezterm.lua" "${windowsWeztermConfigPath}/wezterm.lua.bak"
      echo "Backed up existing Windows WezTerm config to wezterm.lua.bak"
    fi

    if [ -f "${windowsWeztermBridgePath}" ] && [ ! -f "${windowsWeztermBridgePath}.bak" ]; then
      cp "${windowsWeztermBridgePath}" "${windowsWeztermBridgePath}.bak"
      echo "Backed up existing Windows WezTerm bridge to .wezterm.lua.bak"
    fi

    cp "${flakeDirectory}/modules/wezterm/files/wezterm.lua" "${windowsWeztermConfigPath}/wezterm.lua"
    cp "${flakeDirectory}/modules/wezterm/files/windows-bridge.lua" "${windowsWeztermBridgePath}"
    rm -f "${windowsWeztermConfigPath}/shared.lua"

    echo "WezTerm config deployed to Windows:"
    echo "  - Config: ${windowsWeztermConfigPath}"
    echo "  - Bridge: ${windowsWeztermBridgePath}"
  '';
in
{
  xdg.configFile."wezterm/wezterm.lua".source = mkSymlink "files/wezterm.lua";
}
// lib.optionalAttrs isWSL {
  home.activation.weztermWindowsConfig = lib.hm.dag.entryAfter [
    "writeBoundary"
  ] wslActivationScript;
}
