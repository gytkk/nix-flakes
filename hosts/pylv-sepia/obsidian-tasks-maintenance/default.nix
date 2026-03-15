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
    builtins.readFile ./scripts/maintenance.py
  );
in
{
  # systemd timer - KST 자정 실행 (time.timeZone = "Asia/Seoul" 필요)
  systemd.timers.obsidian-tasks-maintenance = {
    description = "Obsidian Tasks Maintenance Timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00:00:00";
      Persistent = true; # 서버 다운 시 부팅 후 실행
      Unit = "obsidian-tasks-maintenance.service";
    };
  };

  # systemd service
  systemd.services.obsidian-tasks-maintenance = {
    description = "Obsidian Tasks Maintenance (due date rollover + archiving)";
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

      # 3. maintenance 실행
      EXIT_CODE=0
      ${obsidian-tasks-maintenance}/bin/obsidian-tasks-maintenance ${vaultPath} || EXIT_CODE=$?

      # 4. sync 재시작 (성공/실패 무관)
      sudo ${pkgs.systemd}/bin/systemctl start obsidian-sync.service || true

      exit $EXIT_CODE
    '';
  };
}
