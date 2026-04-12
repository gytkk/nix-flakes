{
  config,
  lib,
  pkgs,
  inputs,
  osConfig ? null,
  ...
}:

let
  cfg = config.modules.hermes-agent;
  hermesPackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  hermesHome = "${config.home.homeDirectory}/.hermes";
  exampleConfig = "${inputs.hermes-agent}/cli-config.yaml.example";
  systemManaged =
    osConfig != null
    && lib.attrByPath [ "services" "hermes-agent" "enable" ] false osConfig
    && lib.attrByPath [ "services" "hermes-agent" "addToSystemPackages" ] false osConfig;
  systemHermesHome =
    if osConfig != null then
      "${lib.attrByPath [ "services" "hermes-agent" "stateDir" ] "/var/lib/hermes" osConfig}/.hermes"
    else
      null;
in
{
  options.modules.hermes-agent = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Hermes Agent CLI";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.shellAliases = {
        hermes-setup = "hermes setup";
        hermes-doctor = "hermes doctor";
        hermes-migrate-openclaw = "hermes claw migrate";
      };
    })

    (lib.mkIf (cfg.enable && systemManaged) {
      home.sessionVariables = {
        HERMES_HOME = systemHermesHome;
      };
    })

    (lib.mkIf (cfg.enable && !systemManaged) {
      home.packages = [ hermesPackage ];

      home.sessionVariables = {
        HERMES_HOME = hermesHome;
      };

      home.activation.hermesBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        HERMES_HOME=${lib.escapeShellArg hermesHome}

        if [ -L "$HERMES_HOME" ]; then
          ${pkgs.coreutils}/bin/rm -f "$HERMES_HOME"
        fi

        ${pkgs.coreutils}/bin/mkdir -p \
          "$HERMES_HOME" \
          "$HERMES_HOME/cron" \
          "$HERMES_HOME/logs" \
          "$HERMES_HOME/memories" \
          "$HERMES_HOME/profiles" \
          "$HERMES_HOME/sessions" \
          "$HERMES_HOME/skills" \
          "$HERMES_HOME/workspace"

        if [ ! -e "$HERMES_HOME/.env" ]; then
          ${pkgs.coreutils}/bin/touch "$HERMES_HOME/.env"
          ${pkgs.coreutils}/bin/chmod 600 "$HERMES_HOME/.env"
        fi

        if [ ! -e "$HERMES_HOME/config.yaml" ]; then
          ${pkgs.coreutils}/bin/install -m 600 ${lib.escapeShellArg exampleConfig} "$HERMES_HOME/config.yaml"
        fi
      '';
    })
  ];
}
