{ inputs, ... }:

{
  # 각 nixpkgs 버전을 pkgs.X로 접근 가능하게 하는 overlay
  nixpkgs-versions = final: _prev: {
    master = import inputs.nixpkgs-master {
      inherit (final) system;
      config.allowUnfree = true;
    };

    stable-24_05 = import inputs.nixpkgs-24_05 {
      inherit (final) system;
      config.allowUnfree = true;
    };

    stable-25_05 = import inputs.nixpkgs-25_05 {
      inherit (final) system;
      config.allowUnfree = true;
    };

    stable-25_11 = import inputs.nixpkgs-25_11 {
      inherit (final) system;
      config.allowUnfree = true;
    };
  };
}
