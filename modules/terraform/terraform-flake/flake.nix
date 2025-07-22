{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";
  };

  outputs = { self, nixpkgs, nixpkgs-terraform }:
    let
      # 지원하는 시스템 목록
      systems = [ "x86_64-linux" "aarch64-darwin" "aarch64-linux" "x86_64-darwin" ];
      
      # 각 시스템에 대해 outputs 생성
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          
          # Terraform 버전 결정 (환경변수에서만, fallback은 기본값)
          tfVersion = 
            let
              envVersion = builtins.getEnv "TF_VERSION";
            in
              if envVersion != "" then envVersion else "1.12.2";
          
          # terraform 패키지 선택
          terraform = nixpkgs-terraform.packages.${system}.${tfVersion};
        in
        {
          default = pkgs.mkShell {
            buildInputs = [ terraform ];
            
            shellHook = ''
              echo "🚀 Terraform ${tfVersion} environment loaded"
              terraform version
            '';
          };
        });
    };
}