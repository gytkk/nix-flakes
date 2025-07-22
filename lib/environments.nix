{ pkgs, lib, ... }:
{
  # 모든 환경 설정 (environments.nix 파일에서 직접 가져옴)
  allEnvironments = import ../environments.nix;
}
