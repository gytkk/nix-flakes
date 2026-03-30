{ username, ... }:

{
  # nix-darwin 상태 버전
  system.stateVersion = 6;

  # 활성화 스크립트에 필요한 기본 사용자
  system.primaryUser = username;

  # Nix 설정
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # 시스템 쉘
  programs.zsh.enable = true;

  # 호스트 이름
  networking.hostName = "devsisters-macbook";

  # macOS 시스템 기본값
  system.defaults = {
    dock.autohide = true;
    finder.AppleShowAllExtensions = true;
    NSGlobalDomain.AppleShowAllExtensions = true;
  };
}
