{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  cfg = config.modules.openclaw;
  stateDir = toString cfg.stateDir;
  agentCoreDir = ".local/share/openclaw/agent-core";
  extensionsDir = ".local/share/openclaw/extensions";
  gatewaySystemdDropInPath = "${homeDirectory}/.config/systemd/user/openclaw-gateway.service.d/20-nix-runtime.conf";
  agentCoreOutput = import ../../agent-core/nix/render.nix { inherit pkgs; } {
    runtime = "openclaw";
  };
  gatewaySystemdDropIn = pkgs.writeText "20-nix-runtime.conf" ''
    [Service]
    UnsetEnvironment=CLAWDBOT_CONFIG_PATH CLAWDBOT_STATE_DIR
    Environment="LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.libcap ]}"
    ${lib.optionalString cfg.agentCore.enable ''Environment="AGENT_CORE_OPENCLAW_INSTRUCTIONS=${homeDirectory}/${agentCoreDir}/AGENTS.core.md"''}
  '';
  materializeRuntimeTree = pkgs.writeShellApplication {
    name = "materialize-openclaw-runtime-tree";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
    ];
    text = builtins.readFile ./files/materialize-runtime-tree.sh;
  };
in
{
  options.modules.openclaw = {
    enable = lib.mkEnableOption "runtime integration for a user-managed OpenClaw installation";

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "${homeDirectory}/.openclaw";
      description = "Mutable OpenClaw state and installation directory.";
    };

    agentCore.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install shared agent-core instructions, skills, and prompt hook.";
    };

    agentSessionRecordPlugin.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install the repo-managed agent-session-record OpenClaw plugin.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" stateDir;
        message = "modules.openclaw.stateDir must be an absolute path.";
      }
      {
        assertion = !(lib.hasPrefix "/nix/store/" stateDir);
        message = "modules.openclaw.stateDir must point to mutable host storage, not the Nix store.";
      }
    ];

    home.sessionPath = [ "${stateDir}/bin" ];

    home.file = lib.mkMerge [
      (lib.mkIf cfg.agentCore.enable {
        "${agentCoreDir}/AGENTS.core.md".source = "${agentCoreOutput}/AGENTS.core.md";
      })
    ];

    home.activation.materializeOpenClawRuntimeTrees =
      lib.mkIf (cfg.agentCore.enable || cfg.agentSessionRecordPlugin.enable)
        (
          lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            ${lib.optionalString cfg.agentCore.enable ''
              ${materializeRuntimeTree}/bin/materialize-openclaw-runtime-tree \
                ${lib.escapeShellArg "${agentCoreOutput}/skills"} \
                ${lib.escapeShellArg "${homeDirectory}/${agentCoreDir}/skills"}
              ${materializeRuntimeTree}/bin/materialize-openclaw-runtime-tree \
                ${lib.escapeShellArg (toString ./files/extensions/agent-core-context)} \
                ${lib.escapeShellArg "${homeDirectory}/${extensionsDir}/agent-core-context"}
            ''}
            ${lib.optionalString cfg.agentSessionRecordPlugin.enable ''
              ${materializeRuntimeTree}/bin/materialize-openclaw-runtime-tree \
                ${lib.escapeShellArg (toString ./files/extensions/agent-session-record)} \
                ${lib.escapeShellArg "${homeDirectory}/${extensionsDir}/agent-session-record"}
            ''}
          ''
        );

    # OpenClaw rejects symlinked effective service definitions during update
    # ownership checks, so keep this supported Environment drop-in materialized.
    home.activation.materializeOpenClawSystemdDropIn = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      dropInPath=${lib.escapeShellArg gatewaySystemdDropInPath}
      if [ -L "$dropInPath" ]; then
        run ${pkgs.coreutils}/bin/rm "$dropInPath"
      fi
      if [ ! -f "$dropInPath" ] || ! ${pkgs.coreutils}/bin/cmp -s ${gatewaySystemdDropIn} "$dropInPath"; then
        run ${pkgs.coreutils}/bin/install -D -m 0644 ${gatewaySystemdDropIn} "$dropInPath"
      fi
    '';

  };
}
