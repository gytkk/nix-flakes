{ pkgs, lib, ... }:
let
  allHostsRaw = import ../hosts.nix;
in
{
  # Home Manager 환경 설정
  allEnvironments = import ../environments.nix;

  # NixOS 호스트 설정
  allHosts = lib.filterAttrs (_: config: !(config.isDarwin or false)) allHostsRaw;

  # Darwin 호스트 설정
  allDarwinHosts = lib.filterAttrs (_: config: config.isDarwin or false) allHostsRaw;
}
