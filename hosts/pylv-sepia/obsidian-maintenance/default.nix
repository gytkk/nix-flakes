{
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  vaultPath = "${homeDirectory}/obsidian";

  obsidian-headless = pkgs.callPackage ../../../packages/obsidian-headless/package.nix { };

  obsidian-maintenance = pkgs.writers.writePython3Bin "obsidian-maintenance" { } (
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

      # 3. maintenance 실행
      EXIT_CODE=0
      ${obsidian-maintenance}/bin/obsidian-maintenance ${vaultPath} || EXIT_CODE=$?

      # 4. sync 재시작 (성공/실패 무관)
      sudo ${pkgs.systemd}/bin/systemctl start obsidian-sync.service || true

      exit $EXIT_CODE
    '';
  };
}
