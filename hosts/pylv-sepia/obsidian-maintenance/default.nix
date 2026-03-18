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

  # systemd service (obsidian-sync.service가 continuous 모드로 동기화 담당)
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
    environment = {
      GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE = "/run/agenix/gws-credentials";
    };
    script = ''
      ${obsidian-maintenance}/bin/obsidian-maintenance ${vaultPath} ${
        inputs.gws.packages.${pkgs.system}.default
      }/bin/gws
    '';
  };
}
