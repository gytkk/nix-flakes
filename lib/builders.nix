{ inputs, nixpkgs }:
let
  repoOverlays = import ../overlays { inherit inputs; };

  # Common overlays for both Home Manager and NixOS
  commonOverlays = [
    inputs.copyparty.overlays.default
    inputs.nix-zed-extensions.overlays.default
    inputs.flake-stores.overlays.default
    inputs.niri.overlays.niri
    inputs.rust-overlay.overlays.default
    repoOverlays.nixpkgs-versions
    repoOverlays.toolchains
    repoOverlays.package-fixes
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

  # flakeDirectory는 homeDirectory에서 자동 파생
  mkFlakeDirectory = homeDirectory: "${homeDirectory}/development/nix-flakes";
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
        "profile"
      ];
      missingFields = builtins.filter (field: !(builtins.hasAttr field config)) requiredFields;
      pkgs = systemPkgs.${config.system};

      flakeDirectory = config.flakeDirectory or (mkFlakeDirectory config.homeDirectory);

      # Dynamic base module loading based on profile
      baseHomeModule = ../base + "/${config.profile}/home.nix";
      dynamicModules =
        if builtins.pathExists baseHomeModule then
          [ baseHomeModule ]
        else
          throw "Base profile '${config.profile}' not found at ${baseHomeModule}";
    in
    if missingFields != [ ] then
      throw "Missing required fields for ${name}: ${builtins.toString missingFields}"
    else
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit (config) username homeDirectory;
          inherit inputs flakeDirectory;
          themeExports = import ./themes.nix { inherit flakeDirectory; };
          isWSL = config.isWSL or false;
          hasSystemCodexConfig = false;
        };
        modules = [
          inputs.agenix.homeManagerModules.default
        ]
        ++ dynamicModules
        ++ (config.homeModules or [ ]);
      };

  # NixOS Configuration helper function
  mkNixOSConfig =
    name: config:
    let
      requiredFields = [
        "system"
        "username"
        "homeDirectory"
        "profile"
      ];
      missingFields = builtins.filter (field: !(builtins.hasAttr field config)) requiredFields;

      flakeDirectory = config.flakeDirectory or (mkFlakeDirectory config.homeDirectory);

      specialArgs = {
        inherit inputs flakeDirectory;
        inherit (config) username homeDirectory;
        themeExports = import ./themes.nix { inherit flakeDirectory; };
        isWSL = config.isWSL or false;
        hasSystemCodexConfig = true;
      };

      # Derive home config from profile, combine with extra home modules
      homeConfig = ../base + "/${config.profile}/home.nix";
      homeModules = [ homeConfig ] ++ (config.homeModules or [ ]);
      sharedHomeModules = [ inputs.agenix.homeManagerModules.default ];
    in
    if missingFields != [ ] then
      throw "Missing required fields for NixOS host ${name}: ${builtins.toString missingFields}"
    else
      nixpkgs.lib.nixosSystem {
        inherit specialArgs;
        modules = [
          ../modules/codex/system.nix
          inputs.disko.nixosModules.disko
          inputs.home-manager.nixosModules.home-manager
          inputs.agenix.nixosModules.default
          inputs.copyparty.nixosModules.default
          inputs.niri.nixosModules.niri
          inputs.dms.nixosModules.dank-material-shell
          inputs.dms.nixosModules.greeter
          (../hosts + "/${name}/configuration.nix")
          {
            nixpkgs.hostPlatform = config.system;
            nixpkgs.overlays = commonOverlays;
            nixpkgs.config.allowUnfree = true;

            age.secrets."openai-api-key" = {
              file = ../secrets/openai-api-key.age;
              owner = config.username;
              group = "users";
              mode = "0400";
            };

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = specialArgs;
            home-manager.sharedModules = sharedHomeModules;
            home-manager.users.${config.username} = {
              imports = homeModules;
            };
          }
        ]
        ++ (config.extraModules or [ ]);
      };

}
