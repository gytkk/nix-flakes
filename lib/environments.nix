{ pkgs, lib, ... }:
{
  # Home Manager 환경 설정
  allEnvironments = import ../environments.nix;

  # NixOS 호스트 설정
  allHosts = import ../hosts.nix;
}
