{ pkgs, ... }:
{
  # pylv-denim 환경 전용 설정

  modules.agentSessionRecord.remoteHost = "192.168.0.10";

  systemd.user.services.nix-garbage-collect = {
    Unit.Description = "Collect old Nix store paths";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 14d";
    };
  };

  systemd.user.timers.nix-garbage-collect = {
    Unit.Description = "Collect old Nix store paths weekly";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
