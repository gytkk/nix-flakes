{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  gatewayPort = 18789;
  lanProxyPort = 18790;
  lanInterface = "wlo1";
  stateDir = "${homeDirectory}/.openclaw";
  gatewayTokenPath = "${stateDir}/gateway-auth-token";
  gatewayNginxAuthIncludePath = "/etc/openclaw/nginx-gateway-auth.conf";
  openclawBootstrapPath = "/etc/openclaw/bootstrap.sh";
  openclawServicePath = lib.concatStringsSep ":" [
    "/run/current-system/sw/bin"
    "${homeDirectory}/.nix-profile/bin"
    "/etc/profiles/per-user/${username}/bin"
    "${homeDirectory}/.local/bin"
    "${homeDirectory}/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];
  openclawCliPath = lib.concatStringsSep ":" [
    openclawServicePath
    "${homeDirectory}/.npm-global/bin"
    "${homeDirectory}/.volta/bin"
    "${homeDirectory}/.asdf/shims"
    "${homeDirectory}/.bun/bin"
    "${homeDirectory}/.nvm/current/bin"
    "${homeDirectory}/.fnm/current/bin"
    "${homeDirectory}/.local/share/pnpm"
  ];
  openclawSystemdDropInPath = "${homeDirectory}/.config/systemd/user/openclaw-gateway.service.d/20-nix-path.conf";
  openclawSystemdDropInFile = pkgs.writeText "openclaw-gateway-20-nix-path.conf" ''
    [Service]
    # NixOS-specific PATH shim for the hybrid OpenClaw setup.
    Environment=PATH=${openclawServicePath}
  '';
  openclawHybridCli = pkgs.writeShellScriptBin "openclaw" ''
    export OPENCLAW_NIX_MODE=
    # NixOS-specific PATH shim for this hybrid setup.
    export PATH="${openclawCliPath}:$PATH"
    export OPENCLAW_PATH_BOOTSTRAPPED=1

    if [ -r ${pkgs.lib.escapeShellArg openclawBootstrapPath} ]; then
      . ${pkgs.lib.escapeShellArg openclawBootstrapPath}
    fi

    # Call the CLI entrypoint directly instead of the packaged wrapper.
    # The packaged wrapper currently jumps into dist/index.js, while the real
    # entrypoint (dist/entry.js) installs the warning filter that suppresses the
    # noisy Node DEP0040 punycode deprecation warning.
    exec ${pkgs.nodejs}/bin/node ${pkgs."openclaw-gateway"}/lib/openclaw/dist/entry.js "$@"
  '';

  seedConfig = {
    gateway = {
      mode = "local";
      auth.mode = "token";
      port = gatewayPort;
      bind = "loopback";
      http = {
        endpoints.chatCompletions.enabled = true;
      };
      tailscale.mode = "off";
    };
  };

  # Static files for /etc/openclaw/ — written by activationScript, not environment.etc,
  # because nginx-gateway-auth.conf is generated dynamically and shares this directory.
  # environment.etc would symlink the entire directory to the read-only Nix store.
  seedConfigFile = pkgs.writeText "openclaw-seed.json" (builtins.toJSON seedConfig);
  bootstrapScriptFile = pkgs.writeText "openclaw-bootstrap.sh" ''
    # OpenClaw runtime bootstrap for the hybrid Nix + user-managed service setup.
    # Nix provides secret file locations; the wrapper loads only what exists.

    if [ -z "''${DISCORD_BOT_TOKEN-}" ] && [ -r /run/agenix/discord-bot-token ]; then
      export DISCORD_BOT_TOKEN="$(cat /run/agenix/discord-bot-token)"
    fi

    if [ -z "''${BRAVE_API_KEY-}" ] && [ -r /run/agenix/brave-search-api-key ]; then
      export BRAVE_API_KEY="$(cat /run/agenix/brave-search-api-key)"
    fi
  '';
in
{
  age.secrets.discord-bot-token = {
    file = ../../secrets/discord-bot-token.age;
    owner = username;
    group = "users";
    mode = "0400";
  };

  environment.systemPackages = with pkgs; [
    openclawHybridCli
    bun
    nodejs
  ];

  system.activationScripts.openclawSyncGatewayConfig = lib.stringAfter [ "etc" ] ''
    # Ensure /etc/openclaw is a real writable directory.
    # Previous configs used environment.etc which created it as a read-only
    # symlink to the Nix store — incompatible with the dynamic auth conf file.
    if [ -L /etc/openclaw ]; then
      ${pkgs.coreutils}/bin/rm /etc/openclaw
    fi
    ${pkgs.coreutils}/bin/mkdir -p /etc/openclaw

    # Install static Nix-generated config files
    ${pkgs.coreutils}/bin/install -m 444 ${seedConfigFile} /etc/openclaw/openclaw.seed.json
    ${pkgs.coreutils}/bin/install -m 444 ${bootstrapScriptFile} /etc/openclaw/bootstrap.sh

    ${pkgs.coreutils}/bin/install -d -m 755 -o ${username} -g users ${pkgs.lib.escapeShellArg "${homeDirectory}/.config/systemd/user/openclaw-gateway.service.d"}
    ${pkgs.coreutils}/bin/install -m 644 -o ${username} -g users ${openclawSystemdDropInFile} ${pkgs.lib.escapeShellArg openclawSystemdDropInPath}

    CONFIG_FILE=${pkgs.lib.escapeShellArg "${stateDir}/openclaw.json"}
    TOKEN_FILE=${pkgs.lib.escapeShellArg gatewayTokenPath}
    NGINX_AUTH_FILE=${pkgs.lib.escapeShellArg gatewayNginxAuthIncludePath}

    gateway_token=
    if [ -f "$CONFIG_FILE" ]; then
      gateway_token="$(${pkgs.jq}/bin/jq -er '.gateway.auth.token // empty' "$CONFIG_FILE" 2>/dev/null || true)"
    fi

    if [ -z "$gateway_token" ] && [ -s "$TOKEN_FILE" ]; then
      gateway_token="$(${pkgs.coreutils}/bin/cat "$TOKEN_FILE")"
    fi

    if [ -z "$gateway_token" ]; then
      gateway_token="$(${pkgs.openssl}/bin/openssl rand -hex 24)"
    fi

    tmp_token="$(${pkgs.coreutils}/bin/mktemp)"
    printf '%s' "$gateway_token" > "$tmp_token"
    ${pkgs.coreutils}/bin/install -D -o ${username} -g users -m 600 "$tmp_token" "$TOKEN_FILE"
    ${pkgs.coreutils}/bin/rm -f "$tmp_token"

    tmp_auth="$(${pkgs.coreutils}/bin/mktemp)"
    cat > "$tmp_auth" <<EOF
    proxy_set_header Authorization "Bearer $gateway_token";
    EOF
    ${pkgs.coreutils}/bin/install -m 440 -o root -g ${config.services.nginx.group} "$tmp_auth" "$NGINX_AUTH_FILE"
    ${pkgs.coreutils}/bin/rm -f "$tmp_auth"

    if [ ! -f "$CONFIG_FILE" ]; then
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.jq}/bin/jq \
        --arg token "$gateway_token" \
        '
          .gateway.auth.token = $token
        ' \
        ${seedConfigFile} > "$tmp"
      ${pkgs.coreutils}/bin/install -D -o ${username} -g users -m 600 "$tmp" "$CONFIG_FILE"
      ${pkgs.coreutils}/bin/rm -f "$tmp"
    fi
  '';

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."openclaw-lan" = {
      serverName = "_";
      listen = [
        {
          addr = "0.0.0.0";
          port = lanProxyPort;
        }
      ];
      locations."= /v1/models" = {
        return = ''200 '{"object":"list","data":[{"id":"openclaw/main","object":"model","created":0,"owned_by":"openclaw"},{"id":"openclaw/pro","object":"model","created":0,"owned_by":"openclaw"}]}' '';
        extraConfig = ''
          default_type application/json;
          add_header Content-Type application/json always;
        '';
      };
      locations."/v1/" = {
        proxyPass = "http://127.0.0.1:${toString gatewayPort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout 10m;
          proxy_set_header Host $host:$server_port;
          proxy_set_header X-Forwarded-Host $host:$server_port;
          include ${gatewayNginxAuthIncludePath};
        '';
      };
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString gatewayPort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout 10m;
          proxy_set_header Host $host:$server_port;
          proxy_set_header X-Forwarded-Host $host:$server_port;
          include ${gatewayNginxAuthIncludePath};
        '';
      };
    };
  };

  networking.firewall.interfaces = {
    "${lanInterface}".allowedTCPPorts = [ lanProxyPort ];
  };
}
