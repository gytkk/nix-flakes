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
  isOnyx = config.networking.hostName == "pylv-onyx";
  hermesPackage = import ./package.nix { inherit pkgs inputs; };
  hermesStateDir = "/var/lib/hermes";
  hermesHome = "${hermesStateDir}/.hermes";
  hermesEnvFile = "${hermesHome}/.env";
  discordEnvSeedMarker = "${hermesHome}/.discord-env-seeded";
  oneHalfLightSkin = pkgs.writeText "hermes-one-half-light.yaml" ''
    name: one-half-light
    description: One Half Light palette aligned with pylv-onyx terminal tooling

    colors:
      banner_border: "#3a9a88"
      banner_title: "#e8862f"
      banner_accent: "#0184bc"
      banner_dim: "#4f525e"
      banner_text: "#383a42"
      ui_accent: "#0184bc"
      ui_label: "#3a9a88"
      ui_ok: "#50a14f"
      ui_error: "#e45649"
      ui_warn: "#c18401"
      prompt: "#383a42"
      input_rule: "#4a9b79"
      diff_plus_fg: "#50a14f"
      diff_plus_bg: "#edf7ee"
      diff_minus_fg: "#e45649"
      diff_minus_bg: "#fceeed"
      response_border: "#e8862f"
      session_label: "#d4a216"
      session_border: "#4f525e"

    spinner:
      thinking_verbs:
        - "indexing context"
        - "tracing symbols"
        - "resolving paths"
        - "shaping changes"
        - "tightening the diff"
      wings:
        - ["‹", "›"]
        - ["⟨", "⟩"]

    branding:
      agent_name: "Hermes Agent"
      welcome: "Welcome to Hermes Agent! Type your message or /help for commands."
      goodbye: "Goodbye."
      response_label: " Hermes "
      prompt_symbol: "❯ "
      help_header: "Available Commands"

    tool_prefix: "│"
  '';
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
      user = username;
      group = "users";
      createUser = false;
      addToSystemPackages = true;
      package = hermesPackage;
      stateDir = hermesStateDir;
      authFile = "${homeDirectory}/.codex/auth.json";
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
        display = {
          skin = "one-half-light";
          tool_progress = "off";
        };
        model = {
          base_url = "https://chatgpt.com/backend-api/codex";
          default = "gpt-5.4";
          provider = "openai-codex";
        };
        terminal.backend = "local";
      };
    };

    system.activationScripts."hermes-agent-00-cleanup-obsolete-discord-env" =
      lib.stringAfter
        ([ "users" ] ++ lib.optional (config.system.activationScripts ? setupSecrets) "setupSecrets")
        ''
          ${pkgs.coreutils}/bin/rm -f ${hermesStateDir}/discord.env
        '';

    systemd.services.hermes-agent.preStart = ''
      TOKEN_FILE=${lib.escapeShellArg config.age.secrets.hermes-discord-bot-token.path}
      HERMES_ENV_FILE=${lib.escapeShellArg hermesEnvFile}
      SEED_MARKER=${lib.escapeShellArg discordEnvSeedMarker}
      SKILLS_DIR=${lib.escapeShellArg "${hermesHome}/skills"}

      if [ ! -f "$TOKEN_FILE" ] || [ ! -s "$TOKEN_FILE" ]; then
        echo "ERROR: Hermes Discord bot token not found or empty at $TOKEN_FILE" >&2
        exit 1
      fi

      mkdir -p "$(dirname "$HERMES_ENV_FILE")"
      touch "$HERMES_ENV_FILE"
      chmod 0640 "$HERMES_ENV_FILE"

      seed_env_if_missing() {
        key="$1"
        value="$2"

        if ! ${pkgs.gnugrep}/bin/grep -q "^''${key}=" "$HERMES_ENV_FILE"; then
          printf '%s=%s\n' "$key" "$value" >> "$HERMES_ENV_FILE"
        fi
      }

      if [ ! -e "$SEED_MARKER" ]; then
        seed_env_if_missing "DISCORD_ALLOWED_CHANNELS" "1492848425090285668,1492848439510433833,1492848457348812821,1492848476210331770"
        seed_env_if_missing "DISCORD_ALLOWED_USERS" "392300972023611392"
        seed_env_if_missing "DISCORD_HOME_CHANNEL" "1492848425090285668"
        seed_env_if_missing "DISCORD_HOME_CHANNEL_NAME" "hermes-config"
        seed_env_if_missing "DISCORD_REQUIRE_MENTION" "true"
        touch "$SEED_MARKER"
        chmod 0644 "$SEED_MARKER"
      fi

      ${pkgs.gnused}/bin/sed -i '/^DISCORD_BOT_TOKEN=/d' "$HERMES_ENV_FILE"
      printf 'DISCORD_BOT_TOKEN=%s\n' "$(${pkgs.coreutils}/bin/cat "$TOKEN_FILE")" >> "$HERMES_ENV_FILE"
      chmod 0640 "$HERMES_ENV_FILE"

      if [ -d "$SKILLS_DIR" ]; then
        ${pkgs.findutils}/bin/find "$SKILLS_DIR" -type d \
          -exec ${pkgs.coreutils}/bin/chmod u+rwx,g+rws,o-rwx {} + 2>/dev/null || true
        ${pkgs.findutils}/bin/find "$SKILLS_DIR" -type f \
          -exec ${pkgs.coreutils}/bin/chmod u+rw,g+rw,o-rwx {} + 2>/dev/null || true
      fi
    '';

    system.activationScripts."hermes-agent-10-one-half-light-skin" =
      lib.stringAfter [ "hermes-agent-setup" ] ''
        ${pkgs.coreutils}/bin/install -d -o ${username} -g users -m 0750 \
          ${hermesStateDir}/.hermes/skins
        ${pkgs.coreutils}/bin/install -o ${username} -g users -m 0640 \
          ${oneHalfLightSkin} ${hermesStateDir}/.hermes/skins/one-half-light.yaml
      '';
  };
}
