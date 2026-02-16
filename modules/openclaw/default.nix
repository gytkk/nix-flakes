{
  config,
  lib,
  pkgs,
  inputs,
  homeDirectory,
  ...
}:

let
  cfg = config.modules.openclaw;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isMacOS = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  imports = [
    inputs.nix-openclaw.homeManagerModules.openclaw
  ];

  options.modules.openclaw = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable OpenClaw AI assistant gateway";
    };

    discord = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Discord channel";
      };

      tokenFile = lib.mkOption {
        type = lib.types.str;
        default = "/run/agenix/discord-bot-token";
        description = "Path to Discord bot token file (agenix secret)";
      };

      guildId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Discord Guild (Server) ID";
      };

      channelId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Discord Channel ID to allow";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Create Discord token env file and daemon drop-in at activation.
    # The `openclaw gateway` command creates a SEPARATE systemd service
    # (clawdbot-gateway.service) for the actual daemon. Environment variables
    # from openclaw-gateway.service are NOT inherited by the daemon, so we
    # inject DISCORD_BOT_TOKEN via a systemd drop-in on the daemon service.
    home.activation.openclawDiscordEnv = lib.mkIf (isLinux && cfg.discord.enable) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p /tmp/openclaw
        if [ -f "${cfg.discord.tokenFile}" ]; then
          echo "DISCORD_BOT_TOKEN=$(cat ${cfg.discord.tokenFile})" > /tmp/openclaw/env
          chmod 600 /tmp/openclaw/env
        else
          touch /tmp/openclaw/env
        fi

        # Create systemd drop-in for the daemon service (clawdbot-gateway.service)
        # to inject DISCORD_BOT_TOKEN into the daemon's environment
        mkdir -p "$HOME/.config/systemd/user/clawdbot-gateway.service.d"
        cat > "$HOME/.config/systemd/user/clawdbot-gateway.service.d/discord-token.conf" << 'EOF'
        [Service]
        EnvironmentFile=-/tmp/openclaw/env
        EOF
        systemctl --user daemon-reload 2>/dev/null || true
      ''
    );

    # Systemd service configuration for Linux
    # In Nix mode (OPENCLAW_NIX_MODE=1), the gateway runs in the foreground,
    # so the upstream Type=simple is correct. The EnvironmentFile injects the
    # Discord bot token into the gateway process.
    systemd.user.services.openclaw-gateway = lib.mkIf isLinux {
      Install.WantedBy = [ "default.target" ];

      # Load Discord token from env file (created by activation script)
      Service.EnvironmentFile = lib.mkIf cfg.discord.enable [ "-/tmp/openclaw/env" ];
    };

    programs.openclaw = {
      # Exclude tools that conflict with existing packages
      excludeTools = [
        "nodejs"
        "pnpm"
        "git"
        "curl"
        "jq"
        "ripgrep"
        "ffmpeg"
      ];

      # Don't expose plugin packages to avoid conflicts
      exposePluginPackages = false;

      instances.default = {
        enable = true;

        # Use gateway-only package to avoid npm conflict
        package = pkgs.openclaw-gateway;

        stateDir = "${homeDirectory}/.openclaw";
        workspaceDir = "${homeDirectory}/.openclaw/workspace";

        # Systemd configuration for Linux
        systemd = {
          enable = isLinux;
          unitName = "openclaw-gateway";
        };

        # Launchd configuration for macOS
        launchd = {
          enable = isMacOS;
          label = "com.steipete.openclaw.gateway";
        };

        # Gateway configuration
        config = {
          # Gateway settings
          gateway = {
            mode = "local";
            auth = {
              token = "local-gateway-token";
              mode = "token";
            };
            port = 18789;
            bind = "0.0.0.0";
          };

          # Agent defaults
          agents.defaults = {
            workspace = "${homeDirectory}/.openclaw/workspace";
            maxConcurrent = 4;
            subagents.maxConcurrent = 8;
            model.primary = "anthropic/claude-sonnet-4-5";
          };

          # Commands
          commands = {
            native = "auto";
            nativeSkills = "auto";
          };

          # Messages
          messages = {
            ackReactionScope = "group-mentions";
          };

          # Plugins
          plugins.entries.discord.enabled = cfg.discord.enable;

          # Discord channel configuration
          # Token is provided via DISCORD_BOT_TOKEN environment variable (loaded from agenix)
          channels.discord = lib.mkIf cfg.discord.enable {
            enabled = true;
            groupPolicy = "allowlist";

            # DM settings - pairing mode for security
            dm = {
              enabled = true;
              policy = "pairing";
            };

            # Guild configuration
            guilds = lib.mkIf (cfg.discord.guildId != "") {
              "${cfg.discord.guildId}" = {
                requireMention = true;
                channels = lib.mkIf (cfg.discord.channelId != "") {
                  "${cfg.discord.channelId}" = {
                    allow = true;
                    requireMention = true;
                  };
                };
              };
            };
          };

          # Hooks
          hooks.internal = {
            enabled = true;
            entries = {
              session-memory.enabled = true;
              command-logger.enabled = true;
              boot-md.enabled = true;
            };
          };

          # Skills installation
          skills.install.nodeManager = "bun";
        };

        # Plugins disabled for now (unlocked flake reference issue)
        # Enable later: plugins = [ { source = "github:openclaw/nix-steipete-tools?dir=tools/summarize"; } ];
        plugins = [ ];
      };
    };
  };
}
