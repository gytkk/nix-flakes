{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    saml2aws
  ];

  programs.zsh.shellAliases = {
    "awslogin" = "saml2aws login --disable-keychain --force";
  };
};
