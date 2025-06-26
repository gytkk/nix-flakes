{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Authentication
    saml2aws
    vault
  ];

  programs.zsh.shellAliases = {
    "awslogin" = "saml2aws login --disable-keychain --force";
  };

  programs.zsh.envExtra = ''
    export VAULT_ADDR=https://vault.devsisters.cloud
  '';
}
