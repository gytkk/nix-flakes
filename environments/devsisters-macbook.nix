{
  # 시스템 정보
  system = "aarch64-darwin";

  # 사용자 정보
  username = "gyutak";
  homeDirectory = "/Users/gyutak";

  # 환경별 모듈
  extraModules = [
    ../modules/devsisters
    {
      modules.devsisters.enable = true;
    }
  ];
}
