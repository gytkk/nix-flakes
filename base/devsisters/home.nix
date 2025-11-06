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

  # Devsisters 특화 패키지 추가
  home.packages = with pkgs; [
    # Scala (default to 2.12, compatible with existing projects)
    scala_2_12

    # Authentication
    saml2aws
    vault

    # Databricks
    databricks-cli

    # Ruby
    ruby

    # Custom scripts
    (pkgs.writeShellScriptBin "sign" (builtins.readFile ./scripts/sign))
    (pkgs.writeShellScriptBin "login" (builtins.readFile ./scripts/login))
  ];

  # Terraform 모듈 설정
  modules.terraform = {
    versions = [
      "1.12.2"
      "1.11.4"
      "1.10.5"
    ];
    defaultVersion = "1.12.2";
    runEnv = {
      AWS_PROFILE = "saml";
    };
  };

  # Devsisters 특화 Git 설정
  programs.git.settings.user = {
    email = lib.mkForce "gyutak.kim@devsisters.com";
    name = lib.mkForce "Gyutak Kim";
  };

  # Devsisters 특화 환경 변수
  home.sessionVariables = {
    VAULT_ADDR = "https://vault.devsisters.cloud";
    # SBT Java 호환성 설정
    SBT_OPTS = "-Xmx2G -XX:+UseG1GC";
  };

  # XXX(ecl): Add gem binaries to PATH
  home.sessionPath = [
    "$HOME/.gem/ruby/${pkgs.ruby.version.libDir}/bin"
  ];

  # XXX(ecl): Install ecl gem on activation
  home.activation.installEclGem = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.ruby}/bin/gem list -i ecl > /dev/null 2>&1 || \
      ${pkgs.ruby}/bin/gem install ecl
  '';
}
