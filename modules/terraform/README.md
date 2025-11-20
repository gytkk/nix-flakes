# Terraform 모듈

[stackbuilders/nixpkgs-terraform](https://github.com/stackbuilders/nixpkgs-terraform)를 사용한 Terraform 버전 관리 모듈입니다.

## 설정 방법

### 기본 사용법

```nix
modules.terraform = {
  enable = true;
  defaultVersion = "1.12.2";
};
```

### 다중 버전 설정

```nix
modules.terraform = {
  enable = true;
  versions = [ "1.10.2" "1.12.2" "latest" ];
  defaultVersion = "1.12.2";
  installAll = true;
};
```

## 설정 옵션

### `enable`

- **타입**: `bool`
- **기본값**: `true`
- **설명**: Terraform 모듈 활성화

### `versions`

- **타입**: `list of strings`  
- **기본값**: `[ "1.10.2" "1.12.2", "latest" ]`
- **설명**: 설치할 Terraform 버전 목록

### `defaultVersion`

- **타입**: `string`
- **기본값**: `"1.12.2"`
- **설명**: 기본으로 사용할 Terraform 버전

### `installAll`

- **타입**: `bool`
- **기본값**: `false`
- **설명**: 설정된 모든 Terraform 버전 설치

## 셸 별칭

다중 버전이 설치된 경우, 각 버전별로 별칭이 생성됩니다:

- `terraform-1.10.2` → terraform version 1.10.2
- `terraform-1.12.2` → terraform version 1.12.2  
- `terraform-latest` → 최신 terraform version

---

# Direnv 통합

backend.tf 파일의 `required_version`을 자동으로 감지하여 해당 버전의 Terraform을 사용하는 direnv 통합 시스템입니다.

## 작동 방식

각 프로젝트에 로컬 `flake.nix`를 자동 생성하여 환경변수 의존성을 완전히 제거한 개선된 방식을 사용합니다.

### 자동 flake 생성

`.envrc` 파일이 실행될 때 자동으로 다음을 수행합니다:

1. 현재 디렉토리에 `flake.nix`가 없으면 자동 생성
2. 로컬 `backend.tf`, `versions.tf`, `main.tf` 파일에서 `required_version` 파싱
3. 해당 버전의 terraform 환경 로드

## 사용법

### 1. 새 프로젝트 초기화

```bash
cd /path/to/your/terraform/project
~/development/nix-flakes/scripts/init-terraform-project.sh 1.10.2
```

이 명령어는 다음을 수행합니다:
- `backend.tf` 파일 생성 (없는 경우)
- 개선된 `.envrc` 파일 생성 (자동 flake 생성 포함)
- direnv 설정 활성화

### 2. 기존 프로젝트에 추가

기존 Terraform 프로젝트에 direnv를 추가하려면:

```bash
cd /path/to/existing/terraform/project

# 개선된 .envrc 파일 생성
cat > .envrc << 'EOF'
#!/usr/bin/env bash
# Terraform 설정 파일들 변경 감지
watch_file backend.tf
watch_file versions.tf
watch_file main.tf

# 로컬 flake 자동 생성
if [[ ! -f "flake.nix" ]]; then
  cat > flake.nix << 'FLAKE_EOF'
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
            if builtins.pathExists ./backend.tf then
              parseRequiredVersion (builtins.readFile ./backend.tf)
            else if builtins.pathExists ./versions.tf then
              parseRequiredVersion (builtins.readFile ./versions.tf)
            else if builtins.pathExists ./main.tf then
              parseRequiredVersion (builtins.readFile ./main.tf)
            else "1.12.2";
          
          terraform = nixpkgs-terraform.packages.${system}.${tfVersion};
        in
        {
          default = pkgs.mkShell {
            buildInputs = [ terraform ];
            
            shellHook = ''
              echo "🚀 Terraform ${tfVersion} environment loaded from local config"
              terraform version
            '';
          };
        });
    };
}
FLAKE_EOF
fi

use flake
EOF

# direnv 허용
direnv allow
```

### 3. 버전 변경

```bash
~/development/nix-flakes/scripts/switch-terraform-version.sh 1.10.2 "="
```

변경 후 flake를 새로 생성하려면:
```bash
rm flake.nix flake.lock
direnv reload
```

## 지원되는 버전 형식

backend.tf, versions.tf, main.tf에서 다음 형식들이 지원됩니다:

```hcl
terraform {
  # 정확한 버전
  required_version = "= 1.10.2"
  
  # 최소 버전  
  required_version = ">= 1.10.2"
  
  # 범위 버전
  required_version = "~> 1.10.0"
  
  # 복합 조건 (첫 번째 조건만 파싱됨)
  required_version = ">= 1.10.0, < 2.0.0"
}
```

## 테스트

제공된 테스트 프로젝트에서 확인:

```bash
cd ~/development/nix-flakes/test-terraform-project

# backend.tf 내용 확인
cat backend.tf

# direnv 환경 진입
direnv allow

# 예상 출력:
# 🚀 Terraform 1.10.2 environment loaded from local config
# Terraform v1.10.2

# flake.nix가 자동 생성되었는지 확인
ls -la flake.nix
```

## 트러블슈팅

### 올바르지 않은 버전이 로드되는 경우

1. backend.tf 파일의 `required_version` 확인:
```bash
grep required_version backend.tf
```

2. flake 재생성:
```bash
rm flake.nix flake.lock
direnv reload
```

3. 수동 테스트:
```bash
nix develop . --command terraform version
```

### direnv 에러가 발생하는 경우

1. direnv 재허용:
```bash
direnv allow
direnv reload
```

2. .envrc 권한 확인:
```bash
chmod +x .envrc
```

3. flake 유효성 검증:
```bash
nix flake check .
```
