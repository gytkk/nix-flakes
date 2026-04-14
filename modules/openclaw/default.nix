{
  config,
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
  gatewayNginxAuthIncludePath = "/run/openclaw/nginx-gateway-auth.conf";
  openclawBootstrapPath = "/etc/openclaw/bootstrap.sh";
  openclawHybridCli = pkgs.writeShellScriptBin "openclaw" ''
    export OPENCLAW_NIX_MODE=
    export OPENCLAW_PATH_BOOTSTRAPPED=1

    if [ -r ${pkgs.lib.escapeShellArg openclawBootstrapPath} ]; then
      . ${pkgs.lib.escapeShellArg openclawBootstrapPath}
    fi

    exec ${pkgs."openclaw-gateway"}/bin/openclaw "$@"
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
      controlUi = {
        dangerouslyDisableDeviceAuth = true;
        dangerouslyAllowHostHeaderOriginFallback = true;
      };
    };
  };
in
{
  age.secrets.discord-bot-token = {
    file = ../../secrets/discord-bot-token.age;
    owner = username;
    group = "users";
    mode = "0400";
  };

  environment.etc."openclaw/openclaw.seed.json".text = builtins.toJSON seedConfig;

  environment.etc."openclaw/bootstrap.sh".text = ''
    # OpenClaw runtime bootstrap for the hybrid Nix + user-managed service setup.
    # Nix provides secret file locations; the wrapper loads only what exists.

    if [ -z "''${DISCORD_BOT_TOKEN-}" ] && [ -r /run/agenix/discord-bot-token ]; then
      export DISCORD_BOT_TOKEN="$(cat /run/agenix/discord-bot-token)"
    fi

    if [ -z "''${BRAVE_API_KEY-}" ] && [ -r /run/agenix/brave-search-api-key ]; then
      export BRAVE_API_KEY="$(cat /run/agenix/brave-search-api-key)"
    fi
  '';

  environment.systemPackages = with pkgs; [
    openclawHybridCli
    bun
    nodejs
  ];

  system.activationScripts.openclawSyncGatewayConfig = ''
        CONFIG_FILE=${pkgs.lib.escapeShellArg "${stateDir}/openclaw.json"}
        TOKEN_FILE=${pkgs.lib.escapeShellArg gatewayTokenPath}
        NGINX_AUTH_FILE=${pkgs.lib.escapeShellArg gatewayNginxAuthIncludePath}

        gateway_token=
        if [ ! -s "$TOKEN_FILE" ] && [ -f "$CONFIG_FILE" ]; then
          gateway_token="$(${pkgs.jq}/bin/jq -er '.gateway.auth.token // empty' "$CONFIG_FILE" 2>/dev/null || true)"
        fi

        if [ -z "$gateway_token" ]; then
          if [ -s "$TOKEN_FILE" ]; then
            gateway_token="$(${pkgs.coreutils}/bin/cat "$TOKEN_FILE")"
          else
            gateway_token="$(${pkgs.openssl}/bin/openssl rand -hex 24)"
          fi
        fi

        tmp_token="$(${pkgs.coreutils}/bin/mktemp)"
        printf '%s' "$gateway_token" > "$tmp_token"
        ${pkgs.coreutils}/bin/install -D -o ${username} -g users -m 600 "$tmp_token" "$TOKEN_FILE"
        ${pkgs.coreutils}/bin/rm -f "$tmp_token"

        tmp_auth="$(${pkgs.coreutils}/bin/mktemp)"
        cat > "$tmp_auth" <<EOF
    proxy_set_header Authorization "Bearer $gateway_token";
    EOF
        ${pkgs.coreutils}/bin/install -D -o root -g ${config.services.nginx.group} -m 440 "$tmp_auth" "$NGINX_AUTH_FILE"
        ${pkgs.coreutils}/bin/rm -f "$tmp_auth"

        if [ -f "$CONFIG_FILE" ]; then
          tmp="$(${pkgs.coreutils}/bin/mktemp)"
          ${pkgs.jq}/bin/jq \
            --arg token "$gateway_token" \
            --argjson port ${toString gatewayPort} \
            '
              .gateway.mode = "local"
              | .gateway.port = $port
              | .gateway.bind = "loopback"
              | .gateway.auth.mode = "token"
              | .gateway.auth.token = $token
              | del(.gateway.auth.trustedProxy)
              | del(.gateway.trustedProxies)
              | .gateway.http.endpoints.chatCompletions.enabled = true
              | .gateway.tailscale.mode = "off"
              | .gateway.controlUi.dangerouslyDisableDeviceAuth = true
              | .gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback = true
            ' \
            "$CONFIG_FILE" > "$tmp"
          ${pkgs.coreutils}/bin/install -o ${username} -g users -m 600 "$tmp" "$CONFIG_FILE"
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
