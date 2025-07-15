{ pkgs, lib, ... }:
let
  # 환경 이름 목록
  envNames = [
    "devsisters-macbook"
    "devsisters-macstudio"
    "wsl-ubuntu"
  ];

  # features를 extraModules로 변환하는 함수
  featuresToModules = features: lib.optionals (features.devsisters or false) [
    ../modules/devsisters
  ];

  # 환경 설정 로더
  loadEnvironmentConfig =
    name:
    let
      envFile = ../environments + "/${name}.nix";
      rawConfig = if builtins.pathExists envFile then
        import envFile
      else
        throw "Environment config file not found: ${envFile}";
    in
    # features가 있으면 extraModules로 변환
    if builtins.hasAttr "features" rawConfig then
      rawConfig // {
        extraModules = (rawConfig.extraModules or []) ++ (featuresToModules rawConfig.features);
      }
    else
      rawConfig;
in
{
  # 모든 환경 설정
  allEnvironments = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = loadEnvironmentConfig name;
    }) envNames
  );
}
