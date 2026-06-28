{
  inputs,
  pkgs,
  username,
  homeDirectory,
  ...
}:
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
    pkgs.wezterm
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

  xdg.configFile."systemd/user/hermes-gateway.service.d/10-nix-profile-path.conf".text = ''
    [Service]
    Environment="PATH=${homeDirectory}/.hermes/hermes-agent/venv/bin:${homeDirectory}/.hermes/hermes-agent/node_modules/.bin:/run/current-system/sw/bin:${homeDirectory}/.nix-profile/bin:/etc/profiles/per-user/${username}/bin:${homeDirectory}/.local/bin:${homeDirectory}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  '';

  programs.zen-browser.enable = true;
}
