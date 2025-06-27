{ pkgs, lib, ... }:
rec {
  # 공통 설정
  commonSettings = {
    git = {
      userEmail = "gytk.kim@gmail.com";
      userName = "gytkk";
    };
  };

  # 환경 설정 로더
  loadEnvironmentConfig =
    name:
    let
      envFile = ../environments + "/${name}.nix";
      baseConfig =
        if builtins.pathExists envFile then
          import envFile
        else
          throw "Environment config file not found: ${envFile}";
    in
    baseConfig
    // {
      # Git 설정을 사용자명과 공통 이메일로 자동 설정
      git = commonSettings.git;
    };

  # 모든 환경 설정 자동 로드
  allEnvironments =
    let
      envNames = [
        "devsisters-macbook"
        "devsisters-macstudio"
        "wsl-ubuntu"
      ];
    in
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = loadEnvironmentConfig name;
      }) envNames
    );

  # 환경별 설정 (기존 호환성을 위해 유지)
  configs = allEnvironments;

  # 환경 설정 빌더 (기존 호환성을 위해 유지)
  mkEnvironmentConfig = name: config: config;
}
