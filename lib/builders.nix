{ inputs, nixpkgs }:
rec {
  # 패키지 생성 헬퍼 함수 (기존 mkPkgs)
  mkPkgs =
    system:
    import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        inputs.nix-vscode-extensions.overlays.default
      ];
    };

  # 시스템별 패키지 생성
  mkSystemPkgs =
    systems:
    builtins.listToAttrs (
      map (system: {
        name = system;
        value = mkPkgs system;
      }) systems
    );

  # Home Configuration helper function
  mkHomeConfig =
    {
      environmentConfigs,
      baseModules,
    }:
    name: config:
    let
      requiredFields = [
        "system"
        "username"
        "homeDirectory"
      ];
      missingFields = builtins.filter (field: !(builtins.hasAttr field config)) requiredFields;
      pkgs = mkPkgs config.system;
    in
    if missingFields != [ ] then
      throw "Missing required fields for ${name}: ${builtins.toString missingFields}"
    else
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit (config) username homeDirectory;
          environmentConfig = config;
        };
        modules = baseModules ++ (config.extraModules or [ ]);
      };
}
