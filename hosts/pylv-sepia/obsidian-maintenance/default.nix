{
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  vaultPath = "${homeDirectory}/obsidian";

  obsidian-headless = pkgs.callPackage ../../../packages/obsidian-headless/package.nix { };

  obsidian-tasks-maintenance = pkgs.writers.writePython3Bin "obsidian-tasks-maintenance" { } (
    builtins.readFile ./scripts/tasks_maintenance.py
  );

  obsidian-events-maintenance = pkgs.writers.writePython3Bin "obsidian-events-maintenance" { } (
    builtins.readFile ./scripts/events_maintenance.py
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

  # systemd service
  systemd.services.obsidian-maintenance = {
    description = "Obsidian Maintenance (tasks + events)";
    after = [ "obsidian-sync.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      Group = "users";
    };
    script = ''
      # 1. sync 중단 (root 권한)
      sudo ${pkgs.systemd}/bin/systemctl stop obsidian-sync.service || true

      # 2. 최신 상태 pull (Persistent=true로 부팅 직후 실행 시 필요)
      ${obsidian-headless}/bin/ob sync --once --path ${vaultPath} || true

      # 3. tasks maintenance 실행
      EXIT_CODE=0
      TASK_EXIT_CODE=0
      ${obsidian-tasks-maintenance}/bin/obsidian-tasks-maintenance ${vaultPath} || TASK_EXIT_CODE=$?
      if [ "$TASK_EXIT_CODE" -ne 0 ] && [ "$EXIT_CODE" -eq 0 ]; then
        EXIT_CODE=$TASK_EXIT_CODE
      fi

      # 4. events maintenance 실행
      EVENTS_EXIT_CODE=0
      ${obsidian-events-maintenance}/bin/obsidian-events-maintenance ${vaultPath} || EVENTS_EXIT_CODE=$?
      if [ "$EVENTS_EXIT_CODE" -ne 0 ] && [ "$EXIT_CODE" -eq 0 ]; then
        EXIT_CODE=$EVENTS_EXIT_CODE
      fi

      # 5. sync 재시작 (성공/실패 무관)
      sudo ${pkgs.systemd}/bin/systemctl start obsidian-sync.service || true

      exit $EXIT_CODE
    '';
  };
}
