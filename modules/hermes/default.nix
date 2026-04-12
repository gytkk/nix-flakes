{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.hermes;
  hermesPackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  hermesHome = "${config.home.homeDirectory}/.hermes";
  exampleConfig = "${inputs.hermes-agent}/cli-config.yaml.example";
in
{
  options.modules.hermes = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Hermes Agent CLI module";
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
    '';
  };
}
