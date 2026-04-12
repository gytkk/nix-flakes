{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  openWebUiFrontendPort = 8080;
  openWebUiBackendPort = 8081;
  tailscaleServePort = 8444;
  tailscaleFqdn = "${config.networking.hostName}.tailbbb9bf.ts.net";
  lanInterface = "wlo1";
  openclawProxyPort = 18790;
  openclawProxyApiKey = "lan-admin-proxy";
  openclawDefaultModel = "openclaw/main";
  openclawAvailableModels = [
    "openclaw/main"
    "openclaw/pro"
  ];
  openWebUiTrustedEmail = "gytk.kim@gmail.com";
  openWebUiTrustedEmailHeader = "x-open-webui-email";
  openWebUiTrustedNameHeader = "x-open-webui-name";
  openWebUiDataDir = "${config.services.open-webui.stateDir}/data";
  openWebUiMainIcon = "data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%2064%2064'%3E%3Crect%20width='64'%20height='64'%20rx='18'%20fill='%230f172a'/%3E%3Ctext%20x='32'%20y='43'%20text-anchor='middle'%20font-family='Inter,Arial,sans-serif'%20font-size='30'%20font-weight='700'%20fill='white'%3EM%3C/text%3E%3C/svg%3E";
  openWebUiProIcon = "data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%2064%2064'%3E%3Crect%20width='64'%20height='64'%20rx='18'%20fill='%237c3aed'/%3E%3Ctext%20x='32'%20y='43'%20text-anchor='middle'%20font-family='Inter,Arial,sans-serif'%20font-size='30'%20font-weight='700'%20fill='white'%3EP%3C/text%3E%3C/svg%3E";
  openWebUiSeedConfig = builtins.toJSON {
    version = 0;
    ui = { };
    openai.api_configs = {
      "0" = {
        enable = true;
        model_ids = openclawAvailableModels;
      };
    };
  };
in
{
  age.secrets.open-webui-env = {
    file = ../../secrets/open-webui-env.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = openWebUiBackendPort;
    environment = {
      # Seed the persistent config on every start so Open WebUI stays declarative.
      ENABLE_PERSISTENT_CONFIG = "true";

      # Seed the admin account so the first authenticated visitor does not
      # become admin by accident.
      WEBUI_ADMIN_EMAIL = openWebUiTrustedEmail;
      WEBUI_ADMIN_NAME = username;
      ENABLE_SIGNUP = "false";
      DEFAULT_USER_ROLE = "pending";
      ENABLE_LOGIN_FORM = "false";
      ENABLE_PASSWORD_AUTH = "true";
      ENABLE_EVALUATION_ARENA_MODELS = "false";
      ENABLE_OLLAMA_API = "false";
      ENABLE_OPENAI_API = "true";
      WEBUI_AUTH_TRUSTED_EMAIL_HEADER = openWebUiTrustedEmailHeader;
      WEBUI_AUTH_TRUSTED_NAME_HEADER = openWebUiTrustedNameHeader;

      # Route all OpenAI-compatible traffic through the local trusted proxy.
      OPENAI_API_BASE_URL = "http://127.0.0.1:${toString openclawProxyPort}/v1";
      OPENAI_API_KEY = openclawProxyApiKey;
      OPENAI_API_BASE_URLS = "http://127.0.0.1:${toString openclawProxyPort}/v1";
      OPENAI_API_KEYS = openclawProxyApiKey;
      DEFAULT_MODELS = openclawDefaultModel;
      TASK_MODEL_EXTERNAL = openclawDefaultModel;
      FORWARDED_ALLOW_IPS = "127.0.0.1,::1";

      # The app is reachable through Tailscale, the LAN, or a local SSH tunnel.
      CORS_ALLOW_ORIGIN = lib.concatStringsSep ";" [
        "https://${tailscaleFqdn}:${toString tailscaleServePort}"
        "http://${config.networking.hostName}:${toString openWebUiFrontendPort}"
        "http://${config.networking.hostName}.local:${toString openWebUiFrontendPort}"
        "http://192.168.0.10:${toString openWebUiFrontendPort}"
        "http://localhost:3000"
        "http://127.0.0.1:3000"
      ];
      WEBUI_SESSION_COOKIE_SAME_SITE = "strict";
      XFRAME_OPTIONS = "DENY";
      XCONTENT_TYPE = "nosniff";
      REFERRER_POLICY = "strict-origin-when-cross-origin";
      PERMISSIONS_POLICY = "camera=(),microphone=(),geolocation=()";
    };
    environmentFile = config.age.secrets.open-webui-env.path;
  };

  services.nginx.virtualHosts."open-webui-lan" = {
    serverName = "_";
    listen = [
      {
        addr = "0.0.0.0";
        port = openWebUiFrontendPort;
      }
    ];
    locations."/ws/socket.io/" = {
      proxyPass = "http://127.0.0.1:${toString openWebUiBackendPort}";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header ${openWebUiTrustedEmailHeader} ${openWebUiTrustedEmail};
        proxy_set_header ${openWebUiTrustedNameHeader} ${username};
      '';
    };
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString openWebUiBackendPort}";
      extraConfig = ''
        proxy_set_header ${openWebUiTrustedEmailHeader} ${openWebUiTrustedEmail};
        proxy_set_header ${openWebUiTrustedNameHeader} ${username};
      '';
    };
  };

  networking.firewall.interfaces = {
    "${lanInterface}".allowedTCPPorts = [ openWebUiFrontendPort ];
  };

  systemd.services.open-webui.preStart = lib.mkForce ''
    mkdir -p "${openWebUiDataDir}"

    [ -f "${config.services.open-webui.stateDir}/webui.db" ] && mv "${config.services.open-webui.stateDir}/webui.db" "${openWebUiDataDir}/"

    for dir in cache uploads vector_db; do
      [ -d "${config.services.open-webui.stateDir}/$dir" ] && mv "${config.services.open-webui.stateDir}/$dir" "${openWebUiDataDir}/"
    done

    printf '%s\n' ${lib.escapeShellArg openWebUiSeedConfig} > "${openWebUiDataDir}/config.json"
  '';

  systemd.services.open-webui-openclaw-models = {
    description = "Seed Open WebUI model metadata for OpenClaw agents";
    after = [
      "open-webui.service"
      "nginx.service"
    ];
    wants = [
      "open-webui.service"
      "nginx.service"
    ];
    partOf = [
      "open-webui.service"
      "nginx.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      coreutils
      curl
      gnused
      jq
    ];
    script = ''
      set -euo pipefail

      wait_for() {
        local name="$1"
        shift

        for _ in $(seq 1 60); do
          if "$@"; then
            return 0
          fi

          sleep 1
        done

        echo "ERROR: $name did not become ready in time" >&2
        return 1
      }

      make_icon_data_url() {
        local fill="$1"
        local glyph="$2"
        local svg

        svg="<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><rect width='64' height='64' rx='16' fill='$fill'/><text x='32' y='42' font-family='Inter,Arial,sans-serif' font-size='30' font-weight='700' text-anchor='middle' fill='white'>$glyph</text></svg>"

        printf 'data:image/svg+xml;base64,%s' "$(printf '%s' "$svg" | base64 -w0)"
      }

      wait_for "Open WebUI trusted sign-in" sh -c '
        curl --fail --silent --show-error \
          -H "Content-Type: application/json" \
          -d "{\"email\":\"ignored@example.com\",\"password\":\"ignored\"}" \
          "http://127.0.0.1:${toString openWebUiFrontendPort}/api/v1/auths/signin" >/dev/null
      '

      token="$(${pkgs.curl}/bin/curl --fail --silent --show-error \
        -H 'Content-Type: application/json' \
        -d '{"email":"ignored@example.com","password":"ignored"}' \
        "http://127.0.0.1:${toString openWebUiFrontendPort}/api/v1/auths/signin" \
        | ${pkgs.jq}/bin/jq -r '.token')"

      if [ -z "$token" ] || [ "$token" = "null" ]; then
        echo "ERROR: Open WebUI trusted sign-in did not return a token" >&2
        exit 1
      fi

      main_icon="$(make_icon_data_url '#1f6feb' 'M')"
      pro_icon="$(make_icon_data_url '#9b59b6' 'P')"

      payload="$(${pkgs.jq}/bin/jq -n \
        --arg mainIcon "$main_icon" \
        --arg proIcon "$pro_icon" \
        '{
          models: [
            {
              id: "openclaw/main",
              base_model_id: "openclaw/main",
              name: "openclaw/main",
              meta: {
                profile_image_url: $mainIcon,
                description: "OpenClaw main agent"
              },
              params: {},
              is_active: true
            },
            {
              id: "openclaw/pro",
              base_model_id: "openclaw/pro",
              name: "openclaw/pro",
              meta: {
                profile_image_url: $proIcon,
                description: "OpenClaw pro agent"
              },
              params: {},
              is_active: true
            }
          ]
        }')"

      ${pkgs.curl}/bin/curl \
        --fail --silent --show-error \
        -H "Authorization: Bearer $token" \
        -H 'Content-Type: application/json' \
        -d "$payload" \
        "http://127.0.0.1:${toString openWebUiFrontendPort}/api/v1/models/import" >/dev/null
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  systemd.services.open-webui-seed-model-icons = {
    description = "Seed Open WebUI model icons for OpenClaw agents";
    after = [
      "nginx.service"
      "open-webui.service"
    ];
    wants = [
      "nginx.service"
      "open-webui.service"
    ];
    partOf = [
      "nginx.service"
      "open-webui.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      coreutils
      curl
    ];
    script = let
      payload = builtins.toJSON {
        models = [
          {
            id = "openclaw/main";
            name = "openclaw/main";
            meta = {
              profile_image_url = openWebUiMainIcon;
              description = "OpenClaw main agent";
            };
            params = { };
          }
          {
            id = "openclaw/pro";
            name = "openclaw/pro";
            meta = {
              profile_image_url = openWebUiProIcon;
              description = "OpenClaw pro agent";
            };
            params = { };
          }
        ];
      };
    in ''
      wait_for() {
        local name="$1"
        shift

        for _ in $(seq 1 60); do
          if "$@"; then
            return 0
          fi

          sleep 1
        done

        echo "ERROR: $name did not become ready in time" >&2
        return 1
      }

      wait_for "Open WebUI frontend" curl --fail --silent --show-error "http://127.0.0.1:${toString openWebUiFrontendPort}/" >/dev/null

      curl \
        --fail \
        --silent \
        --show-error \
        --header 'Content-Type: application/json' \
        --data ${lib.escapeShellArg payload} \
        "http://127.0.0.1:${toString openWebUiFrontendPort}/api/v1/models/import" >/dev/null
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  systemd.services.tailscale-serve-open-webui = {
    description = "Expose Open WebUI through Tailscale Serve";
    after = [
      "network-online.target"
      "tailscaled.service"
      "nginx.service"
      "open-webui.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
      "nginx.service"
      "open-webui.service"
    ];
    partOf = [
      "tailscaled.service"
      "nginx.service"
      "open-webui.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      coreutils
      curl
      tailscale
    ];
    script = ''
      wait_for() {
        local name="$1"
        shift

        for _ in $(seq 1 60); do
          if "$@"; then
            return 0
          fi

          sleep 1
        done

        echo "ERROR: $name did not become ready in time" >&2
        return 1
      }

      wait_for "tailscaled" tailscale status --json >/dev/null 2>&1
      wait_for "Open WebUI frontend" curl --fail --silent --show-error "http://127.0.0.1:${toString openWebUiFrontendPort}/" >/dev/null

      tailscale serve --yes --bg --https=${toString tailscaleServePort} "127.0.0.1:${toString openWebUiFrontendPort}"
      tailscale serve status --json >/dev/null
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --yes --https=${toString tailscaleServePort} off";
    };
  };
}
