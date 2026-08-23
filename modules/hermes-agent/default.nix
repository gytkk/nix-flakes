{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.hermesAgent;
  pluginDir = ".hermes/plugins/agent-session-record";
  hermesBin = "${config.home.homeDirectory}/.local/bin/hermes";
in
{
  options.modules.hermesAgent = {
    enable = lib.mkEnableOption "Hermes Agent integration";
    sessionRecord.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install and enable the Hermes agent-session-record plugin";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.sessionRecord.enable) {
    home.file."${pluginDir}/plugin.yaml".source = ./files/plugins/agent-session-record/plugin.yaml;
    home.file."${pluginDir}/__init__.py".source = ./files/plugins/agent-session-record/__init__.py;

    home.activation.enableHermesSessionRecordPlugin = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ -x ${lib.escapeShellArg hermesBin} ]; then
        run ${lib.escapeShellArg hermesBin} plugins enable agent-session-record
      else
        warnEcho "Hermes is not installed at ${hermesBin}; agent-session-record plugin was not enabled"
      fi
    '';
  };
}
