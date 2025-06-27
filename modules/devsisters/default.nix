{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Authentication
    saml2aws
    vault
    
    # Custom scripts
    (pkgs.writeShellScriptBin "sign" (builtins.readFile ./scripts/sign))
  ];

  programs.zsh.shellAliases = {
    "awslogin" = "saml2aws login --disable-keychain --force";
  };

  programs.zsh.envExtra = ''
    export VAULT_ADDR=https://vault.devsisters.cloud
  '';
}
