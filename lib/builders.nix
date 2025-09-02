{ inputs, nixpkgs }:
rec {
  # 패키지 생성 헬퍼 함수 (기존 mkPkgs)
  mkPkgs =
    system:
    import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        inputs.nixpkgs-terraform.overlays.default
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
    { baseModules }:
    name: config:
    let
      requiredFields = [
        "system"
        "username"
        "homeDirectory"
        "baseProfile"
      ];
      missingFields = builtins.filter (field: !(builtins.hasAttr field config)) requiredFields;
      pkgs = mkPkgs config.system;
      
      # Dynamic base module loading based on baseProfile
      baseHomeModule = ../base + "/${config.baseProfile}/home.nix";
      dynamicModules = 
        if builtins.pathExists baseHomeModule then
          [ baseHomeModule ]
        else
          throw "Base profile '${config.baseProfile}' not found at ${baseHomeModule}";
    in
    if missingFields != [ ] then
      throw "Missing required fields for ${name}: ${builtins.toString missingFields}"
    else
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit (config) username homeDirectory;
          inherit inputs;
        };
        modules = dynamicModules ++ (config.extraModules or [ ]);
      };
}
