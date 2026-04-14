{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  publicFqdn = "openwebui.pylv.dev";
  openWebUiFrontendPort = 8787;
  openWebUiBackendPort = 8788;
  openWebUiStateDir = "/var/lib/open-webui";
  openWebUiDataDir = "${openWebUiStateDir}/data";
  openclawProxyPort = 18790;
  openclawProxyApiKey = "lan-admin-proxy";
  openclawDefaultModel = "openclaw/main";
  openclawAvailableModels = [
    "openclaw/main"
    "openclaw/pro"
  ];
  openclawModelIcons = {
    "openclaw/main" =
      "data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%2064%2064'%3E%3Crect%20width='64'%20height='64'%20rx='18'%20fill='%23111827'/%3E%3Ctext%20x='32'%20y='43'%20text-anchor='middle'%20font-family='Inter,Arial,sans-serif'%20font-size='30'%20font-weight='700'%20fill='%23f9fafb'%3EM%3C/text%3E%3C/svg%3E";
    "openclaw/pro" =
      "data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%2064%2064'%3E%3Crect%20width='64'%20height='64'%20rx='18'%20fill='%234c1d95'/%3E%3Ctext%20x='32'%20y='43'%20text-anchor='middle'%20font-family='Inter,Arial,sans-serif'%20font-size='30'%20font-weight='700'%20fill='%23f5f3ff'%3EP%3C/text%3E%3C/svg%3E";
  };
  openWebUiTrustedEmail = "gytk.kim@gmail.com";
  openWebUiTrustedEmailHeader = "x-open-webui-email";
  openWebUiTrustedNameHeader = "x-open-webui-name";
  cloudflareTunnelTokenFile = ../../secrets/cloudflare-tunnel-onyx-token.age;
  cloudflareTunnelEnabled = builtins.pathExists cloudflareTunnelTokenFile;
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

  age.secrets.cloudflare-tunnel-onyx-token = lib.mkIf cloudflareTunnelEnabled {
    file = cloudflareTunnelTokenFile;
    owner = "cloudflared";
    group = "cloudflared";
  };

  users.users.cloudflared = lib.mkIf cloudflareTunnelEnabled {
    isSystemUser = true;
    group = "cloudflared";
  };

  users.groups.cloudflared = lib.mkIf cloudflareTunnelEnabled { };

  environment.systemPackages = lib.mkIf cloudflareTunnelEnabled [ pkgs.cloudflared ];

  services.open-webui = {
    enable = true;
    stateDir = openWebUiStateDir;
    host = "127.0.0.1";
    port = openWebUiBackendPort;
    environment = {
      ENABLE_PERSISTENT_CONFIG = "true";
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
      OPENAI_API_BASE_URL = "http://127.0.0.1:${toString openclawProxyPort}/v1";
      OPENAI_API_KEY = openclawProxyApiKey;
      OPENAI_API_BASE_URLS = "http://127.0.0.1:${toString openclawProxyPort}/v1";
      OPENAI_API_KEYS = openclawProxyApiKey;
      DEFAULT_MODELS = openclawDefaultModel;
      TASK_MODEL_EXTERNAL = openclawDefaultModel;
      FORWARDED_ALLOW_IPS = "127.0.0.1,::1";
      CORS_ALLOW_ORIGIN = lib.concatStringsSep ";" [
        "https://${publicFqdn}"
        "http://localhost:3000"
        "http://127.0.0.1:3000"
      ];
      WEBUI_SESSION_COOKIE_SAME_SITE = "strict";
      XFRAME_OPTIONS = "DENY";
      XCONTENT_TYPE = "nosniff";
      REFERRER_POLICY = "strict-origin-when-cross-origin";
      PERMISSIONS_POLICY = "camera=(),microphone=(),geolocation=()";
      WEBUI_BANNERS = builtins.toJSON [
        {
          id = "openclaw-cron";
          type = "info";
          title = "";
          content = ''&#128368; <a href="/apps/openclaw-cron/" target="_blank" style="color:inherit;text-decoration:underline">OpenClaw Cron Dashboard</a> — 예약 작업 상태 확인'';
          dismissible = true;
          timestamp = 1713070800;
        }
      ];
    };
    environmentFile = config.age.secrets.open-webui-env.path;
  };

  systemd.services.open-webui.preStart = lib.mkForce ''
    mkdir -p "${openWebUiDataDir}"

    [ -f "${openWebUiStateDir}/webui.db" ] && mv "${openWebUiStateDir}/webui.db" "${openWebUiDataDir}/"

    for dir in cache uploads vector_db; do
      [ -d "${openWebUiStateDir}/$dir" ] && mv "${openWebUiStateDir}/$dir" "${openWebUiDataDir}/"
    done

    printf '%s\n' ${lib.escapeShellArg openWebUiSeedConfig} > "${openWebUiDataDir}/config.json"
  '';

  services.nginx.virtualHosts."open-webui-origin" = {
    serverName = "_";
    listen = [
      {
        addr = "127.0.0.1";
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
        proxy_read_timeout 10m;
        proxy_set_header ${openWebUiTrustedEmailHeader} ${openWebUiTrustedEmail};
        proxy_set_header ${openWebUiTrustedNameHeader} ${username};
      '';
    };
  };

  systemd.services.open-webui-openclaw-model-metadata = {
    description = "Seed Open WebUI metadata for OpenClaw models";
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
      jq
    ];
    script =
      let
        modelPayloads = builtins.toJSON (
          lib.mapAttrsToList (modelId: profileImageUrl: {
            id = modelId;
            name = modelId;
            meta = {
              profile_image_url = profileImageUrl;
            };
            params = { };
            is_active = true;
          }) openclawModelIcons
        );
      in
      ''
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

              wait_for "Open WebUI trusted frontend" curl --fail --silent --show-error "http://127.0.0.1:${toString openWebUiFrontendPort}/health" >/dev/null

              signin_response=$(curl --fail --silent --show-error \
                -H 'Content-Type: application/json' \
                -d '{"email":"ignored@example.com","password":"ignored"}' \
                "http://127.0.0.1:${toString openWebUiFrontendPort}/api/v1/auths/signin")
              token=$(jq -er '.token' <<<"$signin_response")

              jq -c '.[]' <<'JSON' | while read -r payload; do
        ${modelPayloads}
        JSON
                model_id=$(jq -r '.id' <<<"$payload")
                get_status=$(curl --silent --show-error -o /tmp/open-webui-model.$$.json -w '%{http_code}' \
                  -H "Authorization: Bearer $token" \
                  --get \
                  --data-urlencode "id=$model_id" \
                  "http://127.0.0.1:${toString openWebUiFrontendPort}/api/v1/models/model")

                case "$get_status" in
                  200)
                    endpoint="model/update"
                    ;;
                  404)
                    endpoint="create"
                    ;;
                  *)
                    echo "ERROR: failed to probe Open WebUI model metadata for $model_id (HTTP $get_status)" >&2
                    cat /tmp/open-webui-model.$$.json >&2
                    exit 1
                    ;;
                esac

                write_status=$(curl --silent --show-error -o /tmp/open-webui-model.$$.json -w '%{http_code}' \
                  -H "Authorization: Bearer $token" \
                  -H 'Content-Type: application/json' \
                  -d "$payload" \
                  "http://127.0.0.1:${toString openWebUiFrontendPort}/api/v1/models/$endpoint")

                if [ "$write_status" != 200 ]; then
                  echo "ERROR: failed to upsert Open WebUI model metadata for $model_id via $endpoint (HTTP $write_status)" >&2
                  cat /tmp/open-webui-model.$$.json >&2
                  exit 1
                fi
              done
      '';
    serviceConfig = {
      Type = "oneshot";
      User = "open-webui";
      Group = "open-webui";
    };
  };

  systemd.services.cloudflared-tunnel-open-webui = lib.mkIf cloudflareTunnelEnabled {
    description = "Cloudflare Tunnel for Open WebUI";
    after = [
      "network-online.target"
      "nginx.service"
      "open-webui.service"
    ];
    wants = [
      "network-online.target"
      "nginx.service"
      "open-webui.service"
    ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run \
        --token "$(cat ${config.age.secrets.cloudflare-tunnel-onyx-token.path})"
    '';
    serviceConfig = {
      Restart = "always";
      RestartSec = 5;
      User = "cloudflared";
      Group = "cloudflared";
    };
  };
}
