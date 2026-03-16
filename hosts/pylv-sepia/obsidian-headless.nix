{
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  obsidian-headless = pkgs.callPackage ../../packages/obsidian-headless/package.nix { };
  vaultName = "personal";
  vaultPath = "${homeDirectory}/obsidian/${vaultName}";
in
{
  # Vault 디렉토리 생성
  systemd.tmpfiles.rules = [
    "d ${vaultPath} 0700 ${username} users -"
  ];

  # Obsidian Headless Sync 서비스
  systemd.services.obsidian-sync = {
    description = "Obsidian Headless Sync";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${obsidian-headless}/bin/ob sync --continuous --path ${vaultPath}
    '';
    serviceConfig = {
      Type = "simple";
      User = username;
      Group = "users";
      Restart = "always";
      RestartSec = 30;
    };
  };

  # ob CLI를 PATH에 추가 (초기 설정: ob login, ob sync-setup 등)
  environment.systemPackages = [ obsidian-headless ];
}
