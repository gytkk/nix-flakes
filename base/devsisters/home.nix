{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:

let
  rubyEnv = pkgs.ruby_3_1.withPackages (
    ps: with ps; [
      curses
      nokogiri
    ]
  );

  eclair = pkgs.writeShellScriptBin "ecl" ''
    export PATH="${rubyEnv}/bin:${pkgs.tmux}/bin:$PATH"
    export GEM_PATH="${rubyEnv}/lib/ruby/gems/3.1.0"

    # Create temporary gem home for eclair installation
    TEMP_GEM_HOME=$(mktemp -d)
    export GEM_HOME="$TEMP_GEM_HOME"
    export GEM_PATH="$TEMP_GEM_HOME:${rubyEnv}/lib/ruby/gems/3.1.0"

    # Install eclair gem with native extensions support
    ${rubyEnv}/bin/gem install ecl --version 3.0.4 --no-document --force

    # Execute the actual ecl command
    exec "$TEMP_GEM_HOME/bin/ecl" "$@"
  '';
in
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

    # Required dependencies for eclair
    eclair
    rubyEnv

    # Databricks
    databricks-cli

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
  programs.git = {
    userEmail = lib.mkForce "gyutak.kim@devsisters.com";
    userName = lib.mkForce "Gyutak Kim";
  };

  # Devsisters 특화 환경 변수
  home.sessionVariables = {
    VAULT_ADDR = "https://vault.devsisters.cloud";
    # SBT Java 호환성 설정
    SBT_OPTS = "-Xmx2G -XX:+UseG1GC";
  };
}
