{ inputs, pkgs, ... }:
{
  # pylv-onyx 데스크톱 환경 전용 설정

  imports = [
    ../../modules/hermes-agent
    inputs.zen-browser.homeModules.beta
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
  ];

  # DankMaterialShell
  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true;
    enableSystemMonitoring = true;
    enableDynamicTheming = true;
    enableClipboardPaste = true;
    niri = {
      enableKeybinds = true;
    };
  };

  home.packages = [
    pkgs.alacritty
    pkgs.btop
    pkgs.walker
    pkgs.ghostty
    pkgs.obsidian
    pkgs.wl-clipboard
    pkgs.yazi
    pkgs.zed-editor
    pkgs.pretendard
    pkgs.moonlight-qt
  ];

  # Alt+Space로 walker 실행 (Spotlight 스타일)
  programs.niri.settings.binds = {
    "Alt+Space".action.spawn = "walker";
  };

  programs.zen-browser.enable = true;
}
