{
  config,
  pkgs,
  lib,
  flakeDirectory,
  ...
}:

let
  cfg = config.modules.agentSessionRecord;
  mkSymlink =
    path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/agent-session-record/${path}";
  stateDir = "${config.home.homeDirectory}/.local/state/agent-session-record";
  configFile = ''
    AGENT_SESSION_RECORD_REMOTE_HOST=${lib.escapeShellArg cfg.remoteHost}
    AGENT_SESSION_RECORD_REMOTE_USER=${lib.escapeShellArg cfg.remoteUser}
    AGENT_SESSION_RECORD_REMOTE_BASE_PATH=${lib.escapeShellArg cfg.remoteBasePath}
    AGENT_SESSION_RECORD_LOCAL_SHORT_CIRCUIT_HOST=${lib.escapeShellArg cfg.localShortCircuitHost}
    AGENT_SESSION_RECORD_STATE_DIR=${lib.escapeShellArg stateDir}
    AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR=${lib.escapeShellArg "${config.home.homeDirectory}/.codex/sessions"}
    AGENT_SESSION_RECORD_COREUTILS_BIN=${lib.escapeShellArg "${pkgs.coreutils}/bin"}
    AGENT_SESSION_RECORD_FINDUTILS_BIN=${lib.escapeShellArg "${pkgs.findutils}/bin"}
    AGENT_SESSION_RECORD_JQ_BIN=${lib.escapeShellArg "${pkgs.jq}/bin"}
    AGENT_SESSION_RECORD_SSH_BIN=${lib.escapeShellArg "${pkgs.openssh}/bin"}
    AGENT_SESSION_RECORD_RSYNC_BIN=${lib.escapeShellArg "${pkgs.rsync}/bin"}
  '';
in
{
  options.modules.agentSessionRecord = {
    enable = lib.mkEnableOption "Central agent session transcript upload";
    remoteHost = lib.mkOption {
      type = lib.types.str;
      default = "pylv-onyx";
      description = "SSH host receiving agent session uploads";
    };
    remoteUser = lib.mkOption {
      type = lib.types.str;
      default = "gytkk";
      description = "SSH user for central agent session uploads";
    };
    remoteBasePath = lib.mkOption {
      type = lib.types.str;
      default = "/home/gytkk/agent-sessions";
      description = "Remote base path for agent session uploads";
    };
    localShortCircuitHost = lib.mkOption {
      type = lib.types.str;
      default = "pylv-onyx";
      description = "Host name that should use local copy instead of SSH";
    };
    agents = {
      claude.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Claude session transcript upload hooks";
      };
      codex.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Codex session transcript upload hooks";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."agent-session-record/config.sh".text = configFile;

    home.file.".local/bin/agent-session-upload-worker" = {
      source = mkSymlink "files/agent-session-upload-worker.sh";
      executable = true;
    };

    home.file.".local/bin/claude-session-upload" = lib.mkIf cfg.agents.claude.enable {
      source = mkSymlink "files/claude-session-upload.sh";
      executable = true;
    };

    home.file.".local/bin/codex-stop-upload" = lib.mkIf cfg.agents.codex.enable {
      source = mkSymlink "files/codex-stop-upload.sh";
      executable = true;
    };

    home.file.".local/bin/codex-session-start-sweep" = lib.mkIf cfg.agents.codex.enable {
      source = mkSymlink "files/codex-session-start-sweep.sh";
      executable = true;
    };
  };
}
