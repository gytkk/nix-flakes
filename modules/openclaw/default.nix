args@{
  config,
  inputs,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  common = import ./common.nix args;
in
lib.mkMerge [
  (import ./runtime.nix (args // { inherit common; }))
  (import ./state-sync.nix (args // { inherit common; }))
  (import ./nginx-proxy.nix (args // { inherit common; }))
]
