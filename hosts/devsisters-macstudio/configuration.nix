{ ... }:

{
  imports = [
    ../devsisters-macbook/configuration.nix
  ];

  # 호스트 이름 override
  networking.hostName = "devsisters-macstudio";
}
