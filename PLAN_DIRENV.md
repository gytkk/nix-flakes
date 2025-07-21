# .env 기반 Terraform 버전 관리 with direnv 계획

## 목표

`backend.tf` 파일의 `required_version` 설정을 자동 감지하여 nixpkgs-terraform과 nix-direnv를 이용해 해당 버전의 terraform을 자동으로 사용하도록 설정

## 현재 상황 분석

### 기존 구성 요소

- ✅ `nixpkgs-terraform` 이미 flake input으로 설정됨
- ✅ `modules/terraform/` 모듈이 존재하며 여러 terraform 버전 지원
- ✅ nix-direnv는 zsh 모듈에서 이미 활성화됨

### 한계점

- 현재는 hardcoded된 버전만 지원
- 프로젝트별 동적 버전 설정 불가
- terraform 설정 파일 기반 버전 관리 미지원

## 구현 계획

### 1단계: dotfile 기반 flake 구조 설계

#### 1.1 디렉토리 구조

```text
# Home Manager dotfiles
~/.config/nix-direnv/
├── terraform-flake.nix    # 공통 terraform flake 템플릿
└── lib.nix               # 헬퍼 함수들

# 프로젝트 디렉토리
project-dir/
├── backend.tf             # terraform { required_version = ">= 1.10.2" }
├── main.tf
└── .envrc                 # use flake ~/.config/nix-direnv/terraform-flake.nix
```

#### 1.2 backend.tf 파일 형식

```hcl
# 정확한 버전 지정
terraform {
  required_version = "= 1.10.2"
}

# 최소 버전 지정
terraform {
  required_version = ">= 1.10.2"
}

# 범위 지정
terraform {
  required_version = "~> 1.10.0"
}

# 복합 조건
terraform {
  required_version = ">= 1.10.0, < 2.0.0"
}
```

### 2단계: dotfile 기반 flake 템플릿 생성

#### 2.1 공통 terraform-flake.nix 템플릿 (~/.config/nix-direnv/terraform-flake.nix)

```nix
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
        in {
          backend = if builtins.pathExists backendTf then backendTf else null;
          versions = if builtins.pathExists versionsTf then versionsTf else null;
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
```

#### 2.2 .envrc 템플릿

```bash
#!/usr/bin/env bash
# Terraform 설정 파일들 변경 감지
watch_file backend.tf
watch_file versions.tf

# 공통 terraform flake 사용
use flake ~/.config/nix-direnv/terraform-flake.nix
```

#### 2.3 Home Manager 통합

`modules/terraform/default.nix`에 dotfile 설정 추가:

```nix
# terraform flake dotfile 설치
home.file.".config/nix-direnv/terraform-flake.nix".source = ./terraform-flake.nix;
home.file.".config/nix-direnv/lib.nix".source = ./lib.nix;
```

### 3단계: 기존 terraform 모듈 확장

#### 3.1 동적 버전 지원 추가

현재 `modules/terraform/default.nix`를 확장하여:

- 환경 변수 기반 버전 선택 지원
- 더 많은 terraform 버전 추가
- 프로젝트별 설정 오버라이드 지원

#### 3.2 지원 버전 확장

nixpkgs-terraform에서 제공하는 모든 버전 지원:

```nix
supportedVersions = [
  "1.0.11"
  "1.1.9"
  "1.2.9"
  "1.3.10"
  "1.4.7"
  "1.5.7"
  "1.6.6"
  "1.7.5"
  "1.8.5"
  "1.9.8"
  "1.10.2"
  "1.12.2"
];
```

### 4단계: 헬퍼 스크립트 개발

#### 4.1 프로젝트 초기화 스크립트

```bash
# scripts/init-terraform-project.sh
#!/usr/bin/env bash

TF_VERSION=${1:-"1.12.2"}
PROJECT_DIR=${2:-"."}

cd "$PROJECT_DIR"

# .env 파일 생성
echo "TF_VERSION=$TF_VERSION" > .env

# .envrc 파일 생성
cat > .envrc << 'EOF'
#!/usr/bin/env bash
watch_file .env
use flake ~/.config/nix-direnv/terraform-flake.nix
EOF

# direnv 허용
direnv allow

echo "✅ Terraform $TF_VERSION project initialized"
echo "📁 Using shared flake: ~/.config/nix-direnv/terraform-flake.nix"
```

#### 4.2 버전 전환 스크립트

```bash
# scripts/switch-terraform-version.sh
#!/usr/bin/env bash

NEW_VERSION=$1

if [ -z "$NEW_VERSION" ]; then
  echo "Usage: $0 <terraform-version>"
  exit 1
fi

# .env 파일 업데이트
sed -i "s/TF_VERSION=.*/TF_VERSION=$NEW_VERSION/" .env

# direnv 재로드
direnv reload

echo "✅ Switched to Terraform $NEW_VERSION"
```

### 5단계: 검증 및 테스트

#### 5.1 테스트 시나리오

1. `.env` 파일 생성 후 버전 확인
2. 버전 변경 후 자동 전환 확인  
3. 여러 프로젝트 동시 운영 테스트
4. flake.lock 업데이트 후 일관성 확인

#### 5.2 성능 최적화

- binary cache 활용 확인
- 첫 로드 시간 측정 및 개선
- flake 평가 캐싱 최적화

### 6단계: 문서화 및 가이드

#### 6.1 사용자 가이드 작성

- 프로젝트 초기 설정 방법
- 버전 전환 방법  
- 트러블슈팅 가이드

#### 6.2 모듈 문서 업데이트

- `modules/terraform/README.md` 업데이트
- 새로운 기능 및 옵션 설명 추가

## 구현 우선순위

1. **High Priority**: dotfile 기반 공통 terraform-flake.nix 개발 및 테스트
2. **High Priority**: Home Manager 통합으로 dotfile 자동 설치
3. **Medium Priority**: .env 파일 파싱 로직 구현 및 검증
4. **Medium Priority**: 헬퍼 스크립트 개발
5. **Low Priority**: 기존 terraform 모듈 확장 및 고급 기능

## 예상 이점

1. **프로젝트별 독립성**: 각 프로젝트가 고유한 terraform 버전 사용
2. **버전 일관성**: .env를 통한 명시적 버전 관리  
3. **자동화**: direnv를 통한 환경 자동 전환
4. **재현성**: nix flake를 통한 결정적 빌드
5. **팀 협업**: .env 파일 공유로 동일 환경 보장
6. **중앙 관리**: 단일 dotfile로 모든 프로젝트 관리
7. **버전 관리 간소화**: flake.nix 파일을 각 프로젝트마다 복사할 필요 없음
8. **Home Manager 통합**: 기존 nix-flakes 설정과 자연스럽게 통합

## 잠재적 제약사항

1. **첫 로드 시간**: 새 버전 첫 사용시 다운로드 시간
2. **디스크 사용량**: 여러 버전 동시 설치시 용량 증가
3. **복잡성**: 기존 단순한 설정 대비 복잡도 증가
4. **의존성**: nixpkgs-terraform upstream 의존성

## 대안 방안

만약 .env 파일 파싱이 복잡하다면:

1. **환경 변수 직접 사용**: `TF_VERSION` 환경 변수 직접 참조
2. **설정 파일 사용**: `.terraform-version` 파일 사용 (tfenv 호환)
3. **nix 표현식**: `terraform-version.nix` 파일로 버전 정의
