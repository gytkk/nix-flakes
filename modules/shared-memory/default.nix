{
  config,
  lib,
  pkgs,
  homeDirectory,
  ...
}:
let
  cfg = config.modules.sharedMemory;
  wrapper = pkgs.writeShellScript "openclaw-memory-mcp" ''
    export OPENCLAW_MEMORY_WORKSPACE=${lib.escapeShellArg cfg.workspaceRoot}
    export OPENCLAW_MEMORY_AGENT=${lib.escapeShellArg cfg.agentId}
    export OPENCLAW_MEMORY_COMMAND=${lib.escapeShellArg cfg.openclawCommand}
    export OPENCLAW_MEMORY_TIMEOUT_SECONDS=${lib.escapeShellArg (toString cfg.timeoutSeconds)}
    exec ${pkgs.python3}/bin/python3 ${./files/openclaw_memory_mcp.py}
  '';
in
{
  options.modules.sharedMemory = {
    enable = lib.mkEnableOption "shared OpenClaw memory access for local agents";

    workspaceRoot = lib.mkOption {
      type = lib.types.str;
      default = "${homeDirectory}/development/ws";
      description = "Workspace containing USER.md, MEMORY.md, and memory/**/*.md.";
    };

    agentId = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "OpenClaw agent whose built-in memory index is queried.";
    };

    openclawCommand = lib.mkOption {
      type = lib.types.str;
      default = "${homeDirectory}/.openclaw/bin/openclaw";
      description = "Absolute path to the user-managed OpenClaw executable.";
    };

    timeoutSeconds = lib.mkOption {
      type = lib.types.ints.between 1 300;
      default = 60;
      description = "Maximum duration of an OpenClaw memory search.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.workspaceRoot;
        message = "modules.sharedMemory.workspaceRoot must be an absolute path.";
      }
      {
        assertion = cfg.agentId != "";
        message = "modules.sharedMemory.agentId must not be empty.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.openclawCommand;
        message = "modules.sharedMemory.openclawCommand must be an absolute path.";
      }
    ];

    home.file.".local/bin/openclaw-memory-mcp".source = wrapper;
  };
}
