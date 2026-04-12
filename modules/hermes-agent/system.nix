{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  isOnyx = config.networking.hostName == "pylv-onyx";
  discordEnvFile = "/var/lib/hermes/discord.env";
in
{
  config = lib.mkIf isOnyx {
    age.secrets.hermes-discord-bot-token = {
      file = ../../secrets/hermes-discord-bot-token.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    services.hermes-agent = {
      enable = true;
      user = username;
      group = "users";
      createUser = false;
      addToSystemPackages = true;
      authFile = "${homeDirectory}/.codex/auth.json";
      environmentFiles = [ discordEnvFile ];
      environment = {
        DISCORD_ALLOWED_CHANNELS = "1492848425090285668,1492848439510433833,1492848457348812821,1492848476210331770";
        DISCORD_ALLOWED_USERS = "392300972023611392";
        DISCORD_HOME_CHANNEL = "1492848425090285668";
        DISCORD_HOME_CHANNEL_NAME = "hermes-config";
        DISCORD_REQUIRE_MENTION = "true";
      };
      extraPackages = with pkgs; [
        bun
        curl
        fd
        ffmpeg
        jq
        nodejs
        openssh
        ripgrep
        uv
        wget
      ];
      settings = {
        agent.restart_drain_timeout = 300;
        display.tool_progress = "off";
        model = {
          base_url = "https://chatgpt.com/backend-api/codex";
          default = "gpt-5.4";
          provider = "openai-codex";
        };
        terminal.backend = "local";
      };
    };

    system.activationScripts."hermes-agent-00-discord-env" =
      lib.stringAfter
        ([ "users" ] ++ lib.optional (config.system.activationScripts ? setupSecrets) "setupSecrets")
        ''
          ${pkgs.coreutils}/bin/mkdir -p /var/lib/hermes
          ${pkgs.coreutils}/bin/chown -R ${username}:users /var/lib/hermes
          printf 'DISCORD_BOT_TOKEN=%s\n' "$(${pkgs.coreutils}/bin/cat ${config.age.secrets.hermes-discord-bot-token.path})" > ${discordEnvFile}
          ${pkgs.coreutils}/bin/chown root:root ${discordEnvFile}
          ${pkgs.coreutils}/bin/chmod 0600 ${discordEnvFile}
        '';
  };
}
