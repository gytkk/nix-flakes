{
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  gatewayPort = 18789;
  stateDir = "${homeDirectory}/.openclaw";
in
{
  # Discord bot token for openclaw
  age.secrets.discord-bot-token = {
    file = ../../secrets/discord-bot-token.age;
    owner = username;
    group = "users";
    mode = "0400";
  };

  # OpenClaw Gateway - NixOS system service (runs as the primary user)
  services.openclaw-gateway = {
    enable = true;
    package = pkgs.openclaw-gateway;
    port = gatewayPort;
    user = username;
    group = "users";
    createUser = false;
    stateDir = stateDir;

    # Convert raw agenix token to KEY=VALUE format (runs as root via + prefix)
    # Fail-closed: service won't start if Discord token is missing
    execStartPre = [
      "+${pkgs.writeShellScript "openclaw-discord-env" ''
        TOKEN_FILE="/run/agenix/discord-bot-token"
        ENV_DIR="/run/openclaw"
        ENV_FILE="$ENV_DIR/env"
        ${pkgs.coreutils}/bin/mkdir -p "$ENV_DIR"
        if [ -f "$TOKEN_FILE" ] && [ -s "$TOKEN_FILE" ]; then
          echo "DISCORD_BOT_TOKEN=$(${pkgs.coreutils}/bin/cat "$TOKEN_FILE")" > "$ENV_FILE"
        else
          echo "ERROR: Discord bot token not found or empty at $TOKEN_FILE" >&2
          exit 1
        fi
        ${pkgs.coreutils}/bin/chmod 600 "$ENV_FILE"
        ${pkgs.coreutils}/bin/chown ${username}:users "$ENV_FILE"
      ''}"
    ];
    environmentFiles = [ "-/run/openclaw/env" ];

    servicePath = with pkgs; [
      bun
      nodejs
    ];

    config = {
      gateway = {
        mode = "local";
        auth = {
          # Loopback-only token: not externally reachable (bind = "loopback" + Tailscale serve)
          token = "local-gateway-token";
          mode = "token";
        };
        port = gatewayPort;
        bind = "loopback";
        trustedProxies = [
          "127.0.0.1"
          "::1"
        ];
        tailscale.mode = "serve";
        controlUi = {
          dangerouslyDisableDeviceAuth = true;
          allowedOrigins = [ "https://pylv-sepia.tailbbb9bf.ts.net:8443" ];
        };
      };

      agents = {
        defaults = {
          workspace = "${stateDir}/workspace";
          maxConcurrent = 4;
          subagents.maxConcurrent = 8;
          model.primary = "openai-codex/gpt-5.4";
          thinkingDefault = "xhigh";
        };
        list = [
          {
            id = "main";
            default = true;
            name = "Main";
            model.primary = "openai-codex/gpt-5.4";
          }
          {
            id = "gpt-pro";
            name = "GPT Pro";
            model.primary = "openai-codex/gpt-5.4-pro";
          }
          {
            id = "sonnet";
            name = "Sonnet";
            model.primary = "anthropic/claude-sonnet-4-6";
          }
          {
            id = "opus";
            name = "Opus";
            model.primary = "anthropic/claude-opus-4-6";
          }
        ];
      };

      commands = {
        native = "auto";
        nativeSkills = "auto";
      };

      messages.ackReactionScope = "group-mentions";

      plugins.entries.discord.enabled = true;

      channels.discord = {
        enabled = true;
        groupPolicy = "allowlist";
        dm = {
          enabled = true;
          policy = "pairing";
        };
        guilds."1467867949657227318" = {
          requireMention = true;
          channels."1467867998655217850" = {
            allow = true;
            requireMention = true;
          };
        };
      };

      hooks.internal = {
        enabled = true;
        entries = {
          session-memory.enabled = true;
          command-logger.enabled = true;
          boot-md.enabled = true;
        };
      };

      skills.install.nodeManager = "bun";
    };
  };

  # OpenClaw CLI
  environment.systemPackages = [ pkgs.openclaw-gateway ];
}
