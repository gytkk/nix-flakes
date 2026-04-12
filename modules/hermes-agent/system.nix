{
  config,
  lib,
  pkgs,
  inputs,
  username,
  homeDirectory,
  ...
}:
let
  hermesPackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  stateDir = "${homeDirectory}/.hermes";
  hermesHome = stateDir;
  workingDirectory = "${stateDir}/workspace";
  isOnyx = config.networking.hostName == "pylv-onyx";
in
{
  config = lib.mkIf isOnyx {
    age.secrets.hermes-discord-bot-token = {
      file = ../../secrets/hermes-discord-bot-token.age;
      owner = username;
      group = "users";
      mode = "0400";
    };

    services.hermes-agent = {
      enable = true;
      package = hermesPackage;

      user = username;
      group = "users";
      createUser = false;

      stateDir = stateDir;
      workingDirectory = workingDirectory;
      addToSystemPackages = false;

      settings = {
        model = {
          default = "gpt-5.4";
          provider = "openai-codex";
          base_url = "https://chatgpt.com/backend-api/codex";
        };
        terminal.backend = "local";
        display.tool_progress = "off";
      };

      environment = {
        DISCORD_ALLOWED_CHANNELS = "1492848425090285668,1492848439510433833,1492848457348812821,1492848476210331770";
        DISCORD_ALLOWED_USERS = "392300972023611392";
        DISCORD_HOME_CHANNEL = "1492848425090285668";
        DISCORD_HOME_CHANNEL_NAME = "hermes-config";
        DISCORD_REQUIRE_MENTION = "true";
      };

    };

    systemd.services.hermes-agent = {
      environment = {
        DISCORD_ALLOWED_CHANNELS = "1492848425090285668,1492848439510433833,1492848457348812821,1492848476210331770";
        DISCORD_ALLOWED_USERS = "392300972023611392";
        DISCORD_HOME_CHANNEL = "1492848425090285668";
        DISCORD_HOME_CHANNEL_NAME = "hermes-config";
        DISCORD_REQUIRE_MENTION = "true";
      };

      preStart = ''
        TOKEN_FILE="/run/agenix/hermes-discord-bot-token"
        HERMES_ENV_FILE="${hermesHome}/.env"

        if [ ! -f "$TOKEN_FILE" ] || [ ! -s "$TOKEN_FILE" ]; then
          echo "ERROR: Hermes Discord bot token not found or empty at $TOKEN_FILE" >&2
          exit 1
        fi

        mkdir -p "$(dirname "$HERMES_ENV_FILE")"
        touch "$HERMES_ENV_FILE"

        ${pkgs.gnused}/bin/sed -i '/^DISCORD_BOT_TOKEN=/d' "$HERMES_ENV_FILE"
        printf 'DISCORD_BOT_TOKEN=%s\n' "$(cat "$TOKEN_FILE")" >> "$HERMES_ENV_FILE"
        chown ${username}:users "$HERMES_ENV_FILE"
        chmod 640 "$HERMES_ENV_FILE"
      '';
    };

    environment.sessionVariables.HERMES_SERVICE_HOME = hermesHome;
  };
}
