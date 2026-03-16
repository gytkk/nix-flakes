{
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  vaultPath = "${homeDirectory}/obsidian";

  obsidian-maintenance = pkgs.writers.writePython3Bin "obsidian-maintenance" { flakeIgnore = [ "E501" "E203" ]; } (
    builtins.readFile ./scripts/maintenance.py
  );
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

  # systemd service (obsidian-sync.service가 continuous 모드로 동기화 담당)
  systemd.services.obsidian-maintenance = {
    description = "Obsidian Maintenance (tasks + events)";
    after = [ "obsidian-sync.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      Group = "users";
    };
    script = ''
      ${obsidian-maintenance}/bin/obsidian-maintenance ${vaultPath}
    '';
  };
}
