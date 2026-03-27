{ inputs, pkgs, ... }:
{
  # pylv-onyx 데스크톱 환경 전용 설정

  imports = [
    inputs.zen-browser.homeModules.beta
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
  ];

  # DankMaterialShell
  programs.dank-material-shell = {
    enable = true;
    enableSystemMonitoring = true;
    enableDynamicTheming = true;
    enableClipboardPaste = true;
    niri = {
      enableKeybinds = true;
      enableSpawn = true;
    };
  };

  home.packages = [
    pkgs.ghostty
    pkgs.zed-editor
  ];

  programs.zen-browser.enable = true;
}
