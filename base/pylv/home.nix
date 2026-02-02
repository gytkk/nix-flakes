{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:

{
  # Import base configuration
  imports = [ ../default.nix ];

  # OpenClaw - disabled due to upstream packaging bug (hasown module missing)
  # See: https://github.com/openclaw/nix-openclaw/issues/45
  modules.openclaw.enable = false;

  # Pylv 특화 패키지들 (추후 필요시 추가)
  home.packages = with pkgs; [
    # 추후 필요한 Pylv 특화 도구들 추가 예정
  ];

  # Pylv 특화 shell aliases (추후 필요시 추가)
  home.shellAliases = {
    # 추후 필요한 별칭들 추가 예정
  };

  # Pylv 특화 환경 변수 (추후 필요시 추가)
  home.sessionVariables = {
    # 추후 필요한 환경 변수들 추가 예정
    LESSCHARSET = "utf-8";
  };
}
