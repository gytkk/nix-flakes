{ inputs, nixpkgs }:
let
  # Common overlays for both Home Manager and NixOS
  commonOverlays = [
    inputs.nixpkgs-terraform.overlays.default
    inputs.copyparty.overlays.default
    (import ../overlays { inherit inputs; }).nixpkgs-versions
  ];

  # Pre-evaluated pkgs per system (evaluated once, reused everywhere)
  systemPkgs = {
    "x86_64-linux" = import nixpkgs {
      localSystem = "x86_64-linux";
      config.allowUnfree = true;
      overlays = commonOverlays;
    };
    "aarch64-darwin" = import nixpkgs {
      localSystem = "aarch64-darwin";
      config.allowUnfree = true;
      overlays = commonOverlays;
    };
  };
in
rec {
  # 패키지 생성 헬퍼 함수 - systemPkgs 재사용
  mkPkgs = system: systemPkgs.${system};

  # 시스템별 패키지 생성
  mkSystemPkgs =
    systems:
    builtins.listToAttrs (
      map (system: {
        name = system;
        value = systemPkgs.${system};
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
      pkgs = systemPkgs.${config.system};

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
        inherit specialArgs;
        modules = [
          inputs.disko.nixosModules.disko
          inputs.home-manager.nixosModules.home-manager
          inputs.agenix.nixosModules.default
          inputs.copyparty.nixosModules.default
          (../hosts + "/${name}/configuration.nix")
          {
            nixpkgs.hostPlatform = config.system;
            nixpkgs.overlays = commonOverlays;
            nixpkgs.config.allowUnfree = true;

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = specialArgs;
            home-manager.users.${config.username} = import config.homeConfig;
          }
        ]
        ++ (config.extraModules or [ ]);
      };
}
