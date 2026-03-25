{ inputs, pkgs, ... }:
{
  # pylv-onyx 데스크톱 환경 전용 설정

  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  home.packages = [
    pkgs.ghostty
    pkgs.zed-editor
  ];

  programs.zen-browser = {
    enable = true;
  };
}
