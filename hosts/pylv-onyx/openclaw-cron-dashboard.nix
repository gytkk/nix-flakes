{
  config,
  inputs,
  pkgs,
  lib,
  username,
  ...
}:
let
  openclawPackage = inputs.flake-stores.packages.${pkgs.system}.openclaw;
  bridgePort = 18813;
  pythonEnv = pkgs.python3.withPackages (
    ps: with ps; [
      fastapi
      uvicorn
    ]
  );
  appRoot = ../../apps/openclaw-cron-dashboard;
  frontendDist = pkgs.callPackage ../../packages/openclaw-cron-dashboard-frontend/package.nix { };
in
{
  systemd.services.openclaw-cron-dashboard = {
    description = "OpenClaw Cron Dashboard bridge";
    after = [
      "network-online.target"
      "nginx.service"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      HOME = "/home/${username}";
      OPENCLAW_STATE_DIR = "/home/${username}/.openclaw";
      OPENCLAW_CONFIG_PATH = "/home/${username}/.openclaw/openclaw.json";
      OPENCLAW_BIN = "${openclawPackage}/bin/openclaw";
      OPENCLAW_CRON_DASHBOARD_CORS = lib.concatStringsSep ";" [
        "https://openwebui.pylv.dev"
        "http://127.0.0.1:8787"
      ];
      OPENCLAW_CRON_DASHBOARD_FRONTEND_DIST = "${frontendDist}";
      PYTHONPATH = "${appRoot}/backend";
    };
    serviceConfig = {
      Type = "simple";
      User = username;
      Group = "users";
      WorkingDirectory = "${appRoot}/backend";
      ExecStart = ''
        ${pythonEnv}/bin/uvicorn app:app \
          --host 127.0.0.1 \
          --port ${toString bridgePort}
      '';
      Restart = "always";
      RestartSec = 3;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadOnlyPaths = [ "${appRoot}" ];
      ReadWritePaths = [ "/home/${username}/.openclaw" ];
    };
  };

  services.nginx.virtualHosts."open-webui-origin".locations = {
    "= /admin/openclaw-cron" = {
      return = "302 /apps/openclaw-cron/";
    };

    "/api/openclaw/cron/" = {
      proxyPass = "http://127.0.0.1:${toString bridgePort}/api/openclaw/cron/";
      extraConfig = ''
        proxy_read_timeout 30s;
      '';
    };

    "/apps/openclaw-cron/" = {
      proxyPass = "http://127.0.0.1:${toString bridgePort}/apps/openclaw-cron/";
      extraConfig = ''
        proxy_read_timeout 30s;
      '';
    };
  };
}
