# Terraform Direnv Integration

backend.tf 파일의 `required_version`을 자동으로 감지하여 해당 버전의 Terraform을 사용하는 direnv 통합 시스템입니다.

## 작동 방식

최근 개선된 방식에서는 각 프로젝트에 로컬 `flake.nix`를 자동 생성하여 환경변수 의존성을 완전히 제거했습니다.

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

# 로컬 flake 자동 생성 및 사용
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

## 장점

### 이전 방식 대비 개선사항

1. **환경변수 의존성 제거**: PWD, DIRENV_DIR 등의 환경변수 문제 완전 해결
2. **더 확실한 파일 감지**: `./backend.tf` 상대 경로 사용
3. **프로젝트별 독립성**: 각 프로젝트에 자체 flake 보유
4. **간편한 디버깅**: 로컬 flake.nix로 문제 추적 용이

### 핵심 특징

- **자동 생성**: flake.nix가 없으면 자동으로 생성
- **버전 감지**: backend.tf → versions.tf → main.tf 순서로 탐지
- **캐시 최적화**: nix-direnv 캐시로 빠른 로드
- **표준 호환**: 표준 Terraform 설정 파일 활용

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

## 지원되는 Terraform 버전

nixpkgs-terraform에서 제공하는 모든 버전이 지원됩니다:
- 1.0.11, 1.1.9, 1.2.9, 1.3.10, 1.4.7, 1.5.7
- 1.6.6, 1.7.5, 1.8.5, 1.9.8, 1.10.2, 1.12.2

## 파일 구조

```
your-project/
├── backend.tf                # Terraform 버전 요구사항
├── main.tf                   # Terraform 설정
├── .envrc                    # direnv 설정 (자동 flake 생성)
├── flake.nix                 # 자동 생성된 로컬 flake
└── flake.lock                # nix 의존성 락 파일
```

## 마이그레이션 가이드

기존 중앙집중식 방식에서 새로운 로컬 flake 방식으로 마이그레이션:

```bash
# 기존 .envrc를 새 버전으로 교체
cd your-terraform-project
rm .envrc
~/development/nix-flakes/scripts/init-terraform-project.sh
```

또는 수동으로 .envrc 내용을 위의 "기존 프로젝트에 추가" 섹션대로 업데이트하세요.