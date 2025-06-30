{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Install VSCodium (open-source VS Code)
  home.packages = with pkgs; [
    vscodium
  ];
}