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
      
      # Terraform 설정 파일들 탐지
      findTerraformFiles = dir:
        let 
          backendTf = dir + "/backend.tf";
          versionsTf = dir + "/versions.tf";
          mainTf = dir + "/main.tf";
        in {
          backend = if builtins.pathExists backendTf then backendTf else null;
          versions = if builtins.pathExists versionsTf then versionsTf else null;
          main = if builtins.pathExists mainTf then mainTf else null;
        };
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          
          # 현재 디렉토리에서 Terraform 파일 찾기
          currentDir = builtins.getEnv "PWD";
          terraformFiles = findTerraformFiles (/. + currentDir);
          
          # Terraform required_version 파싱 함수
          parseRequiredVersion = content:
            let
              # required_version 매치 (다양한 형태 지원)
              versionMatch = builtins.match ".*required_version\\s*=\\s*\"([^\"]+)\".*" content;
            in
              if versionMatch != null then
                let 
                  versionSpec = builtins.head versionMatch;
                  # 정확한 버전 (= 1.10.2)
                  exactMatch = builtins.match "=\\s*([0-9\\.]+)" versionSpec;
                  # 최소 버전 (>= 1.10.2)
                  minMatch = builtins.match ">=\\s*([0-9\\.]+).*" versionSpec;
                  # 범위 버전 (~> 1.10.0)
                  rangeMatch = builtins.match "~>\\s*([0-9\\.]+)" versionSpec;
                in
                  if exactMatch != null then builtins.head exactMatch
                  else if minMatch != null then builtins.head minMatch
                  else if rangeMatch != null then builtins.head rangeMatch
                  else "1.12.2"
              else "1.12.2";
          
          # Terraform 버전 결정
          tfVersion = 
            if terraformFiles.backend != null then
              parseRequiredVersion (builtins.readFile terraformFiles.backend)
            else if terraformFiles.versions != null then
              parseRequiredVersion (builtins.readFile terraformFiles.versions)
            else if terraformFiles.main != null then
              parseRequiredVersion (builtins.readFile terraformFiles.main)
            else "1.12.2";  # 기본값
          
          # terraform 패키지 선택
          terraform = nixpkgs-terraform.packages.${system}.${tfVersion};
        in
        {
          default = pkgs.mkShell {
            buildInputs = [ terraform ];
            
            shellHook = ''
              echo "🚀 Terraform ${tfVersion} environment loaded from terraform config"
              echo "📁 Project: ${currentDir}"
              terraform version
            '';
          };
        });
    };
}