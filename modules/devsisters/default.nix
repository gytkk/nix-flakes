{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    # Authentication
    saml2aws
    vault

    # Custom scripts
    (pkgs.writeShellScriptBin "sign" (builtins.readFile ./scripts/sign))
    (pkgs.writeShellScriptBin "login" (builtins.readFile ./scripts/login))
  ];

  programs.zsh.envExtra = ''
    export VAULT_ADDR=https://vault.devsisters.cloud
  '';
}
