{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";
  };

  outputs = { self, nixpkgs, nixpkgs-terraform }:
    let
      systems = [ "x86_64-linux" "aarch64-darwin" "aarch64-linux" "x86_64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      
      parseRequiredVersion = content:
        let
          versionMatch = builtins.match ".*required_version[ ]*=[ ]*\"([^\"]+)\".*" content;
        in
          if versionMatch != null then
            let 
              versionSpec = builtins.head versionMatch;
              exactMatch = builtins.match "=[ ]*([0-9.]+)" versionSpec;
              minMatch = builtins.match ">=[ ]*([0-9.]+).*" versionSpec;
              rangeMatch = builtins.match "~>[ ]*([0-9.]+)" versionSpec;
            in
              if exactMatch != null then builtins.head exactMatch
              else if minMatch != null then builtins.head minMatch
              else if rangeMatch != null then builtins.head rangeMatch
              else "1.12.2"
          else "1.12.2";
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          
          tfVersion = 
            if builtins.pathExists ../backend.tf then
              parseRequiredVersion (builtins.readFile ../backend.tf)
            else if builtins.pathExists ../versions.tf then
              parseRequiredVersion (builtins.readFile ../versions.tf)
            else if builtins.pathExists ../main.tf then
              parseRequiredVersion (builtins.readFile ../main.tf)
            else "1.12.2";
          
          terraform = nixpkgs-terraform.packages.${system}.${tfVersion};
        in
        {
          default = pkgs.mkShell {
            buildInputs = [ terraform ];
            
            shellHook = ''
              echo "🚀 Terraform ${tfVersion} environment loaded from .direnv/flake.nix"
              terraform version
            '';
          };
        });
    };
}
