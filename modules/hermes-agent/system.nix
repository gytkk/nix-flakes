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
  hermesHome = "${homeDirectory}/.hermes";
  legacyServiceRoot = "${homeDirectory}/.hermes-service";
  legacyServiceHome = "${legacyServiceRoot}/.hermes";
  workingDirectory = "${hermesHome}/workspace";
  configMergeScript = pkgs.callPackage "${inputs.hermes-agent}/nix/configMergeScript.nix" { };
  generatedConfigFile = pkgs.writeText "hermes-config.json" (
    builtins.toJSON {
      agent.restart_drain_timeout = 300;
      display.tool_progress = "off";
      model = {
        base_url = "https://chatgpt.com/backend-api/codex";
        default = "gpt-5.4";
        provider = "openai-codex";
      };
      terminal.backend = "local";
    }
  );
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

    systemd.tmpfiles.rules = [
      "d ${hermesHome} 2770 ${username} users - -"
      "d ${hermesHome}/cron 2770 ${username} users - -"
      "d ${hermesHome}/logs 2770 ${username} users - -"
      "d ${hermesHome}/memories 2770 ${username} users - -"
      "d ${hermesHome}/platforms 2770 ${username} users - -"
      "d ${hermesHome}/profiles 2770 ${username} users - -"
      "d ${hermesHome}/sandboxes 2770 ${username} users - -"
      "d ${hermesHome}/sessions 2770 ${username} users - -"
      "d ${hermesHome}/skills 2770 ${username} users - -"
      "d ${workingDirectory} 2770 ${username} users - -"
    ];

    system.activationScripts.hermes-agent-setup =
      lib.stringAfter
        ([ "users" ] ++ lib.optional (config.system.activationScripts ? setupSecrets) "setupSecrets")
        ''
          LEGACY_ROOT=${lib.escapeShellArg legacyServiceRoot}
          LEGACY_HOME=${lib.escapeShellArg legacyServiceHome}
          HERMES_HOME=${lib.escapeShellArg hermesHome}
          WORKSPACE=${lib.escapeShellArg workingDirectory}
          GENERATED_CONFIG=${lib.escapeShellArg generatedConfigFile}

          if [ -L "$HERMES_HOME" ]; then
            ${pkgs.coreutils}/bin/rm -f "$HERMES_HOME"
          fi

          if [ -d "$LEGACY_HOME" ] && [ ! -e "$HERMES_HOME" ]; then
            ${pkgs.coreutils}/bin/mv "$LEGACY_HOME" "$HERMES_HOME"
          fi

          ${pkgs.coreutils}/bin/mkdir -p \
            "$HERMES_HOME" \
            "$HERMES_HOME/cron" \
            "$HERMES_HOME/logs" \
            "$HERMES_HOME/memories" \
            "$HERMES_HOME/platforms" \
            "$HERMES_HOME/profiles" \
            "$HERMES_HOME/sandboxes" \
            "$HERMES_HOME/sessions" \
            "$HERMES_HOME/skills" \
            "$WORKSPACE"

          if [ ! -e "$HERMES_HOME/.env" ]; then
            ${pkgs.coreutils}/bin/touch "$HERMES_HOME/.env"
          fi

          ${configMergeScript} "$GENERATED_CONFIG" "$HERMES_HOME/config.yaml"
          ${pkgs.coreutils}/bin/touch "$HERMES_HOME/.managed"

          ${pkgs.coreutils}/bin/chown ${username}:users \
            "$HERMES_HOME" \
            "$HERMES_HOME/.env" \
            "$HERMES_HOME/.managed" \
            "$HERMES_HOME/config.yaml" \
            "$HERMES_HOME/cron" \
            "$HERMES_HOME/logs" \
            "$HERMES_HOME/memories" \
            "$HERMES_HOME/platforms" \
            "$HERMES_HOME/profiles" \
            "$HERMES_HOME/sandboxes" \
            "$HERMES_HOME/sessions" \
            "$HERMES_HOME/skills" \
            "$WORKSPACE"

          ${pkgs.coreutils}/bin/chmod 2770 \
            "$HERMES_HOME" \
            "$HERMES_HOME/cron" \
            "$HERMES_HOME/logs" \
            "$HERMES_HOME/memories" \
            "$HERMES_HOME/platforms" \
            "$HERMES_HOME/profiles" \
            "$HERMES_HOME/sandboxes" \
            "$HERMES_HOME/sessions" \
            "$HERMES_HOME/skills" \
            "$WORKSPACE"
          ${pkgs.coreutils}/bin/chmod 0640 "$HERMES_HOME/.env" "$HERMES_HOME/config.yaml"
          ${pkgs.coreutils}/bin/chmod 0644 "$HERMES_HOME/.managed"

          if [ -d "$LEGACY_ROOT" ] && [ ! -d "$LEGACY_HOME" ] && [ "$LEGACY_ROOT" != "$HERMES_HOME" ]; then
            ${pkgs.coreutils}/bin/rm -rf \
              "$LEGACY_ROOT/.cache" \
              "$LEGACY_ROOT/.local" \
              "$LEGACY_ROOT/home" \
              "$LEGACY_ROOT/workspace"
            ${pkgs.coreutils}/bin/rmdir "$LEGACY_ROOT" 2>/dev/null || true
          fi
        '';

    systemd.services.hermes-agent = {
      description = "Hermes Agent Gateway";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        DISCORD_ALLOWED_CHANNELS = "1492848425090285668,1492848439510433833,1492848457348812821,1492848476210331770";
        DISCORD_ALLOWED_USERS = "392300972023611392";
        DISCORD_HOME_CHANNEL = "1492848425090285668";
        DISCORD_HOME_CHANNEL_NAME = "hermes-config";
        DISCORD_REQUIRE_MENTION = "true";
        HOME = homeDirectory;
        HERMES_HOME = hermesHome;
        HERMES_MANAGED = "true";
        MESSAGING_CWD = workingDirectory;
      };

      path = with pkgs; [
        hermesPackage
        bash
        bun
        coreutils
        curl
        fd
        ffmpeg
        findutils
        git
        gnugrep
        gnused
        jq
        nodejs
        openssh
        ripgrep
        uv
        wget
      ];

      preStart = ''
        TOKEN_FILE="/run/agenix/hermes-discord-bot-token"
        HERMES_ENV_FILE="${hermesHome}/.env"

        if [ ! -f "$TOKEN_FILE" ] || [ ! -s "$TOKEN_FILE" ]; then
          echo "ERROR: Hermes Discord bot token not found or empty at $TOKEN_FILE" >&2
          exit 1
        fi

        ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$HERMES_ENV_FILE")"
        ${pkgs.coreutils}/bin/touch "$HERMES_ENV_FILE"

        ${pkgs.gnused}/bin/sed -i '/^DISCORD_BOT_TOKEN=/d' "$HERMES_ENV_FILE"
        printf 'DISCORD_BOT_TOKEN=%s\n' "$(${pkgs.coreutils}/bin/cat "$TOKEN_FILE")" >> "$HERMES_ENV_FILE"
        ${pkgs.coreutils}/bin/chown ${username}:users "$HERMES_ENV_FILE"
        ${pkgs.coreutils}/bin/chmod 0640 "$HERMES_ENV_FILE"
      '';

      serviceConfig = {
        User = username;
        Group = "users";
        WorkingDirectory = workingDirectory;
        ExecStart = "${hermesPackage}/bin/hermes gateway";
        Restart = "always";
        RestartSec = 5;
        UMask = "0007";
        NoNewPrivileges = true;
        ProtectHome = false;
        ProtectSystem = "strict";
        PrivateTmp = true;
        ReadWritePaths = [ hermesHome ];
      };
    };
  };
}
