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

  # DMS가 자체 polkit agent를 제공하므로 niri-flake의 polkit agent 비활성화
  systemd.user.services.niri-flake-polkit.enable = false;

  home.packages = [
    pkgs.alacritty
    pkgs.fuzzel
    pkgs.ghostty
    pkgs.zed-editor
    pkgs.pretendard
    pkgs.moonlight-qt
  ];

  programs.zen-browser.enable = true;
}
