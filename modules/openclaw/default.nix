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
  trustedProxyUser = "lan-admin";
  trustedProxyUserHeader = "x-openclaw-user";
  trustedProxyRequiredHeader = "x-openclaw-proxy";
  trustedProxyRequiredValue = "1";
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
      auth = {
        mode = "trusted-proxy";
        trustedProxy = {
          userHeader = trustedProxyUserHeader;
          requiredHeaders = [ trustedProxyRequiredHeader ];
          allowUsers = [ trustedProxyUser ];
        };
      };
      port = gatewayPort;
      bind = "loopback";
      trustedProxies = [
        "127.0.0.1"
        "::1"
      ];
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

    if [ -f "$CONFIG_FILE" ]; then
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.jq}/bin/jq \
        --arg userHeader ${pkgs.lib.escapeShellArg trustedProxyUserHeader} \
        --arg requiredHeader ${pkgs.lib.escapeShellArg trustedProxyRequiredHeader} \
        --arg allowUser ${pkgs.lib.escapeShellArg trustedProxyUser} \
        --argjson port ${toString gatewayPort} \
        '
          .gateway.mode = "local"
          | .gateway.port = $port
          | .gateway.bind = "loopback"
          | .gateway.auth.mode = "trusted-proxy"
          | .gateway.auth.trustedProxy.userHeader = $userHeader
          | .gateway.auth.trustedProxy.requiredHeaders = [$requiredHeader]
          | .gateway.auth.trustedProxy.allowUsers = [$allowUser]
          | .gateway.trustedProxies = ["127.0.0.1", "::1"]
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
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString gatewayPort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout 10m;
          proxy_set_header Host $host:$server_port;
          proxy_set_header X-Forwarded-Host $host:$server_port;
          proxy_set_header ${trustedProxyUserHeader} ${trustedProxyUser};
          proxy_set_header ${trustedProxyRequiredHeader} ${trustedProxyRequiredValue};
        '';
      };
    };
  };

  networking.firewall.interfaces = {
    "${lanInterface}".allowedTCPPorts = [ lanProxyPort ];
  };
}
