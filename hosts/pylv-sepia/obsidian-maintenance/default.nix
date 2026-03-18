{
  pkgs,
  inputs,
  username,
  homeDirectory,
  ...
}:
let
  vaultPath = "${homeDirectory}/obsidian";

  obsidian-maintenance = pkgs.writers.writePython3Bin "obsidian-maintenance" {
    flakeIgnore = [
      "E501"
      "E203"
    ];
  } (builtins.readFile ./scripts/maintenance.py);
in
{
  # systemd timer - 1시간마다 실행
  systemd.timers.obsidian-maintenance = {
    description = "Obsidian Maintenance Timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      Unit = "obsidian-maintenance.service";
    };
  };

  # agenix secret - gws credentials
  age.secrets.gws-credentials = {
    file = ../../../secrets/gws-credentials.age;
    owner = username;
    mode = "0400";
  };

  # systemd service - 매시간 tasks/events 처리
  systemd.services.obsidian-maintenance = {
    description = "Obsidian Maintenance (tasks + events)";
    after = [
      "obsidian-sync.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      Group = "users";
    };
    script = ''
      ${obsidian-maintenance}/bin/obsidian-maintenance ${vaultPath}
    '';
  };

  # systemd timer - 30초마다 Google Calendar 동기화
  systemd.timers.obsidian-gcal-sync = {
    description = "Obsidian Google Calendar Sync Timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "30s";
      AccuracySec = "1s";
      Unit = "obsidian-gcal-sync.service";
    };
  };

  # systemd service - Google Calendar 동기화
  systemd.services.obsidian-gcal-sync = {
    description = "Obsidian Google Calendar Sync";
    after = [
      "obsidian-sync.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      Group = "users";
    };
    environment = {
      GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE = "/run/agenix/gws-credentials";
    };
    script = ''
      ${obsidian-maintenance}/bin/obsidian-maintenance ${vaultPath} --calendar-only ${
        inputs.gws.packages.${pkgs.system}.default
      }/bin/gws
    '';
  };
}
