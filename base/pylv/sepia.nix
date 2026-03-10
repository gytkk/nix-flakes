{ ... }:
{
  # pylv-sepia 환경 전용 설정
  # OpenClaw: NixOS 시스템 서비스로 전환 (hosts/pylv-sepia/configuration.nix)

  # 서버 환경에서 불필요한 GUI 모듈 비활성화
  modules.zed.enable = false;
}
