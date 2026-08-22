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
  configFile = builtins.toJSON {
    AGENT_SESSION_RECORD_REMOTE_HOST = cfg.remoteHost;
    AGENT_SESSION_RECORD_REMOTE_USER = cfg.remoteUser;
    AGENT_SESSION_RECORD_REMOTE_BASE_PATH = cfg.remoteBasePath;
    AGENT_SESSION_RECORD_LOCAL_SHORT_CIRCUIT_HOST = cfg.localShortCircuitHost;
    AGENT_SESSION_RECORD_SCOPE = cfg.scope;
    AGENT_SESSION_RECORD_STATE_DIR = stateDir;
    AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR = "${config.home.homeDirectory}/.codex/sessions";
    AGENT_SESSION_RECORD_SSH_BIN = "${pkgs.openssh}/bin";
    AGENT_SESSION_RECORD_RSYNC_BIN = "${pkgs.rsync}/bin";
  };
  disabledHook = pkgs.writeTextFile {
    name = "agent-session-record-disabled";
    executable = true;
    text = ''
      #!${pkgs.coreutils}/bin/true
    '';
  };
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
    scope = lib.mkOption {
      type = lib.types.enum [
        "personal"
        "organization"
      ];
      default = "personal";
      description = "Trust scope recorded in capture manifests";
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

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      xdg.configFile."agent-session-record/config.json".text = configFile;

      home.file.".local/bin/agent-session-upload-worker".source =
        mkSymlink "files/agent_session_upload_worker.py";

      home.file.".local/bin/claude-session-upload".source = lib.mkIf cfg.agents.claude.enable (
        mkSymlink "files/claude_session_upload.py"
      );

      home.file.".local/bin/codex-stop-upload".source = lib.mkIf cfg.agents.codex.enable (
        mkSymlink "files/codex_stop_upload.py"
      );

      home.file.".local/bin/codex-session-start-sweep".source = lib.mkIf cfg.agents.codex.enable (
        mkSymlink "files/codex_session_start_sweep.py"
      );
    })

    (lib.mkIf (!cfg.enable || !cfg.agents.claude.enable) {
      home.file.".local/bin/claude-session-upload".source = disabledHook;
    })

    (lib.mkIf (!cfg.enable || !cfg.agents.codex.enable) {
      home.file.".local/bin/codex-stop-upload".source = disabledHook;
      home.file.".local/bin/codex-session-start-sweep".source = disabledHook;
    })
  ];
}
