{
  "devsisters-macbook" = {
    # 시스템 정보
    system = "aarch64-darwin";

    # 사용자 정보
    username = "gyutak";
    homeDirectory = "/Users/gyutak";

    # Base profile
    baseProfile = "devsisters";
  };

  "devsisters-macstudio" = {
    # 시스템 정보
    system = "aarch64-darwin";

    # 사용자 정보
    username = "gyutak";
    homeDirectory = "/Users/gyutak";

    # Base profile
    baseProfile = "devsisters";
  };

  "pylv-denim" = {
    # 시스템 정보
    system = "x86_64-linux";

    # 사용자 정보
    username = "gytkk";
    homeDirectory = "/home/gytkk";

    # Base profile
    baseProfile = "pylv";

    # 환경별 추가 패키지
    extraPackages = pkgs: [];
  };

  "pylv-sepia" = {
    # 시스템 정보
    system = "x86_64-linux";

    # 사용자 정보
    username = "gytkk";
    homeDirectory = "/home/gytkk";

    # Base profile
    baseProfile = "pylv";

    # 환경별 추가 패키지
    extraPackages = pkgs: with pkgs; [ ];
  };
}