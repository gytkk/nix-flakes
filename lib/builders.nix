{ inputs, nixpkgs }:
let
  # Common overlays for both Home Manager and NixOS
  commonOverlays = [
    inputs.nixpkgs-terraform.overlays.default
    (import ../overlays { inherit inputs; }).nixpkgs-versions
  ];
in
rec {
  # 패키지 생성 헬퍼 함수 (기존 mkPkgs)
  mkPkgs =
    system:
    import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = commonOverlays;
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
          isWSL = config.isWSL or false;
        };
        modules = dynamicModules ++ (config.extraModules or [ ]);
      };

  # NixOS Configuration helper function
  mkNixOSConfig =
    name: config:
    let
      requiredFields = [
        "system"
        "username"
        "homeDirectory"
        "homeConfig"
      ];
      missingFields = builtins.filter (field: !(builtins.hasAttr field config)) requiredFields;

      specialArgs = {
        inherit inputs;
        inherit (config) username homeDirectory;
        isWSL = config.isWSL or false;
      };
    in
    if missingFields != [ ] then
      throw "Missing required fields for NixOS host ${name}: ${builtins.toString missingFields}"
    else
      nixpkgs.lib.nixosSystem {
        system = config.system;
        inherit specialArgs;
        modules = [
          inputs.disko.nixosModules.disko
          inputs.home-manager.nixosModules.home-manager
          (../hosts + "/${name}/configuration.nix")
          {
            nixpkgs.overlays = commonOverlays;
            nixpkgs.config.allowUnfree = true;

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = specialArgs;
            home-manager.users.${config.username} = import config.homeConfig;
          }
        ] ++ (config.extraModules or [ ]);
      };
}
