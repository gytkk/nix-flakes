{
  description = "Self-contained non-nixpkgs app packages for nix-flakes.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];

      forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f system);

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

      packagesFor = system: import ./. { pkgs = pkgsFor system; };

      appNames = builtins.attrNames (packagesFor "x86_64-linux");

      packageFor = system: name: (packagesFor system).${name};

      mkPackages =
        system:
        if appNames == [ ] then
          { }
        else
          let
            defaultName = builtins.head appNames;
          in
          builtins.listToAttrs (
            [
              {
                name = "default";
                value = packageFor system defaultName;
              }
            ]
            ++ map (name: {
              name = name;
              value = packageFor system name;
            }) appNames
          );

      mkChecks =
        system:
        let
          buildChecks = builtins.listToAttrs (
            map (name: {
              name = "${name}-build";
              value = packageFor system name;
            }) appNames
          );
        in
        buildChecks;

      mkApps =
        system:
        builtins.listToAttrs (
          map (
            name:
            let
              pkg = packageFor system name;
            in
            {
              name = name;
              value = {
                type = "app";
                meta = {
                  description = pkg.meta.description or "${name} app";
                  mainProgram = pkg.meta.mainProgram or name;
                };
                program = "${pkg}/bin/${pkg.meta.mainProgram or name}";
              };
            }
          ) appNames
        );
    in
    {

      packages = forEachSystem mkPackages;
      checks = forEachSystem mkChecks;
      apps = forEachSystem mkApps;

      overlays.default = final: _prev: import ./. { pkgs = final; };

      legacyPackages = forEachSystem (
        system:
        let
          packages = packagesFor system;
        in
        builtins.listToAttrs (
          map (name: {
            name = name;
            value = packages.${name};
          }) appNames
        )
      );
    };
}
