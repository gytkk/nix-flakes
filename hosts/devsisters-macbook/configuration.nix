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

  # AeroSpace 타일링 윈도우 매니저
  services.aerospace = {
    enable = true;
    settings = {
      # 윈도우 간격
      gaps = {
        inner.horizontal = 10;
        inner.vertical = 10;
        outer.left = 10;
        outer.bottom = 10;
        outer.top = 10;
        outer.right = 10;
      };

      # 키 바인딩
      mode.main.binding = {
        # 포커스 이동
        alt-h = "focus left";
        alt-j = "focus down";
        alt-k = "focus up";
        alt-l = "focus right";

        # 윈도우 이동
        alt-shift-h = "move left";
        alt-shift-j = "move down";
        alt-shift-k = "move up";
        alt-shift-l = "move right";

        # 워크스페이스 전환
        alt-1 = "workspace 1";
        alt-2 = "workspace 2";
        alt-3 = "workspace 3";
        alt-4 = "workspace 4";
        alt-5 = "workspace 5";

        # 윈도우를 워크스페이스로 이동
        alt-shift-1 = "move-node-to-workspace 1";
        alt-shift-2 = "move-node-to-workspace 2";
        alt-shift-3 = "move-node-to-workspace 3";
        alt-shift-4 = "move-node-to-workspace 4";
        alt-shift-5 = "move-node-to-workspace 5";

        # 레이아웃
        alt-slash = "layout tiles horizontal vertical";
        alt-comma = "layout accordion horizontal vertical";
        alt-f = "fullscreen";

        # 리사이즈
        alt-shift-minus = "resize smart -50";
        alt-shift-equal = "resize smart +50";
      };
    };
  };

  # macOS 시스템 기본값
  system.defaults = {
    dock.autohide = true;
    finder.AppleShowAllExtensions = true;
    NSGlobalDomain.AppleShowAllExtensions = true;
  };
}
