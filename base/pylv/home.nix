{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:

let
  discordoTokenSecretFile = ../../secrets/discordo-token.age;
in
{
  # Import base configuration
  imports = [ ../default.nix ];

  # Pylv 특화 패키지들 (추후 필요시 추가)
  home.packages = with pkgs; [
    discordo
  ];

  age.secrets.discordo-token = lib.mkIf (builtins.pathExists discordoTokenSecretFile) {
    file = discordoTokenSecretFile;
  };

  # Pylv 특화 shell aliases (추후 필요시 추가)
  home.shellAliases = {
    discord = "discordo";
  };

  # Pylv 특화 환경 변수 (추후 필요시 추가)
  home.sessionVariables = {
    # 추후 필요한 환경 변수들 추가 예정
    LESSCHARSET = "utf-8";
  };

  programs.zsh.initContent = lib.mkAfter ''
    if [ -z "''${DISCORDO_TOKEN-}" ] && [ -r /run/agenix/discordo-token ]; then
      export DISCORDO_TOKEN="$(cat /run/agenix/discordo-token)"
    fi
  '';
}
