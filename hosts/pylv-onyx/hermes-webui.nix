{
  config,
  inputs,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  hermesWebUiPort = 8787;
  hermesWebUiBackendPort = 8788;
  tailscaleServePort = 8445;
  cloudflareTunnelTokenFile = ../../secrets/cloudflare-tunnel-onyx-token.age;
  cloudflareTunnelEnabled = builtins.pathExists cloudflareTunnelTokenFile;
  hermesWebUiStateDir = "/var/lib/hermes-webui";
  hermesHome = "${homeDirectory}/.hermes";
  hermesConfigPath = "${hermesHome}/config.yaml";
  hermesWorkspace = "${hermesHome}/workspace";
  hermesPackage = import ../../modules/hermes-agent/package.nix { inherit pkgs inputs; };
  hermesWebUiSrc = inputs.hermes-webui.outPath;
  hermesWebUiThemeAssets = ../../modules/hermes-agent/files;
  hermesWebUiThemeName = "one-half-light";
  proxyPassTarget = "http://127.0.0.1:${toString hermesWebUiBackendPort}";
  proxyHeaders = ''
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Host $http_host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
  '';
in
{
  age.secrets.hermes-webui-env = {
    file = ../../secrets/hermes-webui-env.age;
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

  systemd.services.hermes-webui = {
    description = "Hermes WebUI";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      HOME = homeDirectory;
      HERMES_HOME = hermesHome;
      HERMES_CONFIG_PATH = hermesConfigPath;
      HERMES_WEBUI_AGENT_DIR = hermesPackage.pythonSitePackages;
      HERMES_WEBUI_DEFAULT_MODEL = "gpt-5.4";
      HERMES_WEBUI_DEFAULT_WORKSPACE = hermesWorkspace;
      HERMES_WEBUI_HOST = "127.0.0.1";
      HERMES_WEBUI_PORT = toString hermesWebUiBackendPort;
      HERMES_WEBUI_SKIP_ONBOARDING = "1";
      HERMES_WEBUI_STATE_DIR = hermesWebUiStateDir;
      PYTHONPATH = lib.concatStringsSep ":" [
        hermesPackage.sitecustomize
        hermesPackage.pythonSitePackages
      ];
    };
    serviceConfig = {
      Type = "simple";
      User = username;
      Group = "users";
      WorkingDirectory = hermesWebUiSrc;
      ExecStart = "${hermesPackage.pythonExecutable} ${hermesWebUiSrc}/server.py";
      EnvironmentFile = config.age.secrets.hermes-webui-env.path;
      Restart = "on-failure";
      RestartSec = "5s";
      StateDirectory = "hermes-webui";
      StateDirectoryMode = "0750";
      UMask = "0077";
    };
  };

  system.activationScripts."hermes-webui-10-one-half-light-seed" = lib.stringAfter [ "users" ] ''
    state_dir=${lib.escapeShellArg hermesWebUiStateDir}
    settings_file="$state_dir/settings.json"
    seed_marker="$state_dir/.one-half-light-theme-seeded"

    ${pkgs.coreutils}/bin/install -d -o ${username} -g users -m 0750 "$state_dir"

    if [ ! -e "$seed_marker" ]; then
      tmp_file="$(${pkgs.coreutils}/bin/mktemp)"

      if [ -s "$settings_file" ]; then
        if ! ${pkgs.jq}/bin/jq '.theme = "${hermesWebUiThemeName}"' \
          "$settings_file" > "$tmp_file"; then
          printf '{\n  "theme": "%s"\n}\n' ${lib.escapeShellArg hermesWebUiThemeName} > "$tmp_file"
        fi
      else
        printf '{\n  "theme": "%s"\n}\n' ${lib.escapeShellArg hermesWebUiThemeName} > "$tmp_file"
      fi

      ${pkgs.coreutils}/bin/install -o ${username} -g users -m 0600 \
        "$tmp_file" "$settings_file"
      ${pkgs.coreutils}/bin/rm -f "$tmp_file"

      ${pkgs.coreutils}/bin/touch "$seed_marker"
      ${pkgs.coreutils}/bin/chown ${username}:users "$seed_marker"
      ${pkgs.coreutils}/bin/chmod 0640 "$seed_marker"
    fi
  '';

  services.nginx.virtualHosts."hermes-webui-origin" = {
    serverName = "_";
    listen = [
      {
        addr = "127.0.0.1";
        port = hermesWebUiPort;
      }
    ];
    locations."/static/nix-flakes/" = {
      alias = "${hermesWebUiThemeAssets}/";
      extraConfig = ''
        add_header Cache-Control "no-store";
      '';
    };
    locations."/api/chat/stream" = {
      proxyPass = proxyPassTarget;
      extraConfig = ''
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 1h;
        ${proxyHeaders}
      '';
    };
    locations."/api/sessions/gateway/stream" = {
      proxyPass = proxyPassTarget;
      extraConfig = ''
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 1h;
        ${proxyHeaders}
      '';
    };
    locations."/" = {
      proxyPass = proxyPassTarget;
      extraConfig = ''
        client_max_body_size 25m;
        proxy_buffering off;
        proxy_read_timeout 10m;
        proxy_set_header Accept-Encoding "";
        sub_filter_once on;
        sub_filter_types text/html;
        sub_filter '</head>' '<link rel="stylesheet" href="/static/nix-flakes/hermes-webui-one-half-light.css"></head>';
        sub_filter '</body>' '<script src="/static/nix-flakes/hermes-webui-one-half-light.js"></script></body>';
        ${proxyHeaders}
      '';
    };
  };

  systemd.services.cloudflared-tunnel-hermes-webui = lib.mkIf cloudflareTunnelEnabled {
    description = "Cloudflare Tunnel for Hermes WebUI";
    after = [
      "network-online.target"
      "nginx.service"
      "hermes-webui.service"
    ];
    wants = [
      "network-online.target"
      "nginx.service"
      "hermes-webui.service"
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

  systemd.services.tailscale-serve-hermes-webui = {
    description = "Expose Hermes WebUI through Tailscale Serve";
    after = [
      "network-online.target"
      "tailscaled.service"
      "nginx.service"
      "hermes-webui.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
      "nginx.service"
      "hermes-webui.service"
    ];
    partOf = [
      "tailscaled.service"
      "nginx.service"
      "hermes-webui.service"
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
      wait_for "Hermes WebUI frontend" curl --fail --silent --show-error "http://127.0.0.1:${toString hermesWebUiPort}/health" >/dev/null

      tailscale serve --yes --bg --https=${toString tailscaleServePort} "127.0.0.1:${toString hermesWebUiPort}"
      tailscale serve status --json >/dev/null
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --yes --https=${toString tailscaleServePort} off";
    };
  };
}
