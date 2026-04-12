{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.hermes-agent;
  hermesPackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  defaultHermesHome = "${config.home.homeDirectory}/.hermes";
  serviceHermesHome = "${config.home.homeDirectory}/.hermes-service/.hermes";
  hermesHome = if cfg.useServiceHome then serviceHermesHome else defaultHermesHome;
  exampleConfig = "${inputs.hermes-agent}/cli-config.yaml.example";
in
{
  options.modules.hermes-agent = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Hermes Agent CLI module";
    };

    useServiceHome = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use ~/.hermes-service/.hermes as the default HERMES_HOME for CLI sessions.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ hermesPackage ];

    home.sessionVariables = {
      HERMES_HOME = hermesHome;
    };

    home.shellAliases = {
      hermes-setup = "hermes setup";
      hermes-doctor = "hermes doctor";
      hermes-migrate-openclaw = "hermes claw migrate";
    };

    home.activation.hermesBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      HERMES_HOME=${lib.escapeShellArg hermesHome}
      DEFAULT_HERMES_HOME=${lib.escapeShellArg defaultHermesHome}
      SERVICE_HERMES_HOME=${lib.escapeShellArg serviceHermesHome}

      ${pkgs.coreutils}/bin/mkdir -p \
        "$HERMES_HOME" \
        "$HERMES_HOME/cron" \
        "$HERMES_HOME/logs" \
        "$HERMES_HOME/memories" \
        "$HERMES_HOME/profiles" \
        "$HERMES_HOME/sessions" \
        "$HERMES_HOME/skills"

      if [ ! -e "$HERMES_HOME/.env" ]; then
        ${pkgs.coreutils}/bin/touch "$HERMES_HOME/.env"
        ${pkgs.coreutils}/bin/chmod 600 "$HERMES_HOME/.env"
      fi

      if [ ! -e "$HERMES_HOME/config.yaml" ]; then
        ${pkgs.coreutils}/bin/install -m 600 ${lib.escapeShellArg exampleConfig} "$HERMES_HOME/config.yaml"
      fi

      ${lib.optionalString cfg.useServiceHome ''
        if [ -d "$DEFAULT_HERMES_HOME" ] && [ ! -L "$DEFAULT_HERMES_HOME" ] && [ "$DEFAULT_HERMES_HOME" != "$SERVICE_HERMES_HOME" ]; then
          backup="$HOME/.hermes.backup.$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
          ${pkgs.coreutils}/bin/mv "$DEFAULT_HERMES_HOME" "$backup"
        fi
        ${pkgs.coreutils}/bin/ln -sfn "$SERVICE_HERMES_HOME" "$DEFAULT_HERMES_HOME"
      ''}
    '';
  };
}
