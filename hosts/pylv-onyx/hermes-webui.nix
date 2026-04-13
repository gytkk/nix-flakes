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
  tailscaleFqdn = "${config.networking.hostName}.tailbbb9bf.ts.net";
  lanInterface = "wlo1";
  hermesWebUiStateDir = "/var/lib/hermes-webui";
  hermesHome = "${homeDirectory}/.hermes";
  hermesConfigPath = "${hermesHome}/config.yaml";
  hermesWorkspace = "${hermesHome}/workspace";
  hermesPackage = import ../../modules/hermes-agent/package.nix { inherit pkgs inputs; };
  hermesWebUiSrc = inputs.hermes-webui.outPath;
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

  services.nginx.virtualHosts."hermes-webui-lan" = {
    serverName = "_";
    listen = [
      {
        addr = "0.0.0.0";
        port = hermesWebUiPort;
      }
    ];
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
        ${proxyHeaders}
      '';
    };
  };

  networking.firewall.interfaces = {
    "${lanInterface}".allowedTCPPorts = [ hermesWebUiPort ];
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
