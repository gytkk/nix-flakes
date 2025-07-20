{ pkgs, lib, ... }:
let
  # 환경 이름 목록
  envNames = [
    "devsisters-macbook"
    "devsisters-macstudio"
    "wsl-ubuntu"
    "pylv-sepia"
  ];

  # 환경 설정 로더
  loadEnvironmentConfig =
    name:
    let
      envFile = ../environments + "/${name}.nix";
    in
    if builtins.pathExists envFile then
      import envFile
    else
      throw "Environment config file not found: ${envFile}";
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
