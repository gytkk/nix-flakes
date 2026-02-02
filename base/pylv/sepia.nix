{
  config,
  lib,
  pkgs,
  ...
}:

{
  # pylv-sepia 환경 전용 설정

  # OpenClaw AI assistant 활성화
  modules.openclaw.enable = true;
}
