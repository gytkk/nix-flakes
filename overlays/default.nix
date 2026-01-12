{ inputs, ... }:

{
  # 각 nixpkgs 버전을 pkgs.X로 접근 가능하게 하는 overlay
  # Lazy import: 실제 사용되는 패키지만 import하여 evaluation 시간 단축
  nixpkgs-versions =
    final: _prev:
    let
      system = final.stdenv.hostPlatform.system;
      config = {
        allowUnfree = true;
      };

      # Lazy import helper - 패키지가 실제로 접근될 때만 nixpkgs를 import
      mkLazyPkgs =
        nixpkgsInput: packages:
        builtins.listToAttrs (
          map (name: {
            inherit name;
            value = (import nixpkgsInput { inherit system config; }).${name};
          }) packages
        );
    in
    {
      # stable-24_05: turbo만 사용
      stable-24_05 = mkLazyPkgs inputs.nixpkgs-24_05 [
        "turbo"
      ];

      # stable-25_05: ruby_3_2, micromamba 사용
      stable-25_05 = mkLazyPkgs inputs.nixpkgs-25_05 [
        "ruby_3_2"
        "micromamba"
      ];

      # master, stable-25_11: 현재 사용되지 않음 - 필요시 패키지 추가
      master = mkLazyPkgs inputs.nixpkgs-master [ ];
      stable-25_11 = mkLazyPkgs inputs.nixpkgs-25_11 [ ];
    };
}
