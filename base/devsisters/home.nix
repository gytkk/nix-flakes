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
  imports = [
    ../default.nix
    ../../modules/terraform
  ];

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
    pkgs.stable-25_05.ruby_3_2

    # Custom scripts
    (pkgs.writeShellScriptBin "sign" (builtins.readFile ./scripts/sign))
    (pkgs.writeShellScriptBin "login" (builtins.readFile ./scripts/login))
  ];

  # Terraform 모듈 설정
  modules.terraform = {
    enable = true;
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
    # OTEL telemetry (Databricks)
    OTEL_METRICS_EXPORTER = "otlp";
    OTEL_EXPORTER_OTLP_METRICS_PROTOCOL = "http/protobuf";
    OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = "https://devsisters-dsusw2.cloud.databricks.com/api/2.0/otel/v1/metrics";
    OTEL_METRIC_EXPORT_INTERVAL = "10000";
    OTEL_LOGS_EXPORTER = "otlp";
    OTEL_EXPORTER_OTLP_LOGS_PROTOCOL = "http/protobuf";
    OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = "https://devsisters-dsusw2.cloud.databricks.com/api/2.0/otel/v1/logs";
    OTEL_LOGS_EXPORT_INTERVAL = "5000";
    OTEL_LOG_USER_PROMPTS = "1";
  };

  # Databricks OTEL token (decrypted by agenix)
  age.secrets.databricks-token = {
    file = ../../secrets/databricks-token.age;
  };

  # Construct OTEL headers at runtime using the decrypted token
  programs.zsh.initContent = lib.mkAfter ''
    if [ -f "${config.age.secrets.databricks-token.path}" ]; then
      _dbx_token=$(cat "${config.age.secrets.databricks-token.path}")
      export OTEL_EXPORTER_OTLP_METRICS_HEADERS="content-type=application/x-protobuf,Authorization=Bearer $_dbx_token,X-Databricks-UC-Table-Name=ml.ai_observability.cc_otel_metrics"
      export OTEL_EXPORTER_OTLP_LOGS_HEADERS="content-type=application/x-protobuf,Authorization=Bearer $_dbx_token,X-Databricks-UC-Table-Name=ml.ai_observability.cc_otel_logs"
      unset _dbx_token
    fi
  '';

  # Add gem binaries to PATH
  home.sessionPath = [
    "$HOME/.gem/ruby/3.2.0/bin"
  ];
}
